Valid = require('jsonschema').Validator
Validator = new Valid
assert = require 'assert'
Promise = require 'bluebird'
async = require 'async'
needle = Promise.promisifyAll(require('needle'))

schema_zebra =
    name: "zebra"
    type: "object"
    required: true
    additionalProperties: false
    properties:
        hostname: {"type":"string", "required":false}
        password: {"type":"string", "required":true}
        'enable-password': {"type":"string", "required":false}
        'log-file': {"type":"string", "required":false}
        interfaces:
            name: "interfaces"
            type: "array"
            items:
                type: "object"
                required: false
                additionalProperties: false
                properties:
                    name: {type:"string",required:"false"}
                    description: {type:"string", required:false}
                    'link-detect': {"type":"boolean", "required":false}
                    'ip-address': {"type":"string", "required":false}
         'ip-route':        {"type":"string", "required":false}
         'ip-forwarding':   {"type":"boolean", "required":false}
         'no-ip-forwarding':   {"type":"boolean", "required":false}
         'ipv6-forwarding':   {"type":"boolean", "required":false}
         'line':        {"type":"string", "required":false}

schema_ospfd =
    name: "ospfd"
    type: "object"
    additionalProperties: false
    properties:
        hostname: {"type":"string", "required":false}
        password: {"type":"string", "required":true}
        'enable-password': {"type":"string", "required":false}
        'log-file': {"type":"string", "required":false}
        iprouting:
            name: "ospf routing"
            type: "object"
            required:false
            additionalProperties: false
            properties:
                interfaces:
                    name: "interfaces"
                    type: "array"
                    items:
                        name: "interface"
                        type: "object"
                        required: false
                        additionalProperties: false
                        properties:
                            name: {type:"string", required:false}
                            description: {type:"string", required:false}
                            ip:
                                name: "ip"
                                type: "array"
                                items:
                                    type: "object"
                                    required: false
                                    additionalProperties: false
                                    properties:
                                        ospfConfig: {type:"string", required:false}
                router:
                    name: "ospf"
                    type: "object"
                    required: false
                    additionalProperties: false
                    properties:
                        name: {type:"string", required:false}
                        'default-information': {type:"string", required:false}
                        'ospf-rid': {type:"string", required:false}
                        networks:
                            name: "networks"
                            type: "array"
                            items:
                                name: "network"
                                type: "object"
                                required:false
                                additionalProperties: false
                                properties:
                                    ipaddr: {type:"string", required:false}
                        redistribute:
                            name: "redistribute"
                            type: "array"
                            items:
                                name: "redis"
                                type: "object"
                                required: false
                                additionalProperties: false
                                properties:
                                    redis: {type:"string", required:false}
        'line': {"type":"string", "required":false}

schema =
    "zebra": schema_zebra
    "ospfd": schema_ospfd

getPromise = ->
    return new Promise (resolve, reject) ->
        resolve()


Validate =  (obj, schema, callback) ->
    options = {}
    options.propertyName = schema.name
    res = Validator.validate(obj, schema, options)
    console.log "quagga-storm.Validate: #{schema.name}:\n", res.errors
    if res.errors?.length then return false else return true


Start =  (context, entry, mservice, svcInfo) ->
    if context.bInstalledPackages
        serviceData = @serviceMgr.services.get mservice.id
        service = serviceData.data
        @slog.info method:'startService', minion:entry.id, service:service, minionServiceEntry:mservice,  "setting up service in the minion"

        switch service?.name
            when 'quagga-clearpath'
                configObj = service?.factoryConfig.config
                return entry unless configObj?
            
                quaggaConfig = configObj['quagga-clearpath']
                Configs = []
                if quaggaConfig.enable and quaggaConfig.coreConfig
                    Configs.push {name: 'zebra', config: quaggaConfig.coreConfig}
                if quaggaConfig.protocol.ospf.enable and quaggaConfig.protocol.ospf.config
                    Configs.push {name: 'ospfd', config: quaggaConfig.protocol.ospf.config}

                getPromise()
                .then (resp) =>
                    console.log "quagga-storm.Start: Verify ", resp

                    Promise.map Configs, (Config) ->
                        needle.postAsync context.baseUrl+ "/quagga/#{Config.name}", Config.config, json:true
                        .then (resp) =>
                            throw new Error 'invalidStatusCode' unless resp[0].statusCode is 200
                            { name: Config.name, id: resp[1].id }
                        .catch (err) =>
                            throw err

                    .then (resp) =>
                        resp

                    .catch (err) =>
                        console.log "quagga-storm.Start 1: resp ", err

                .then (resp) =>
                    if resp
                        resp = resp.filter (instance) =>
                            return true if instance

                        for svc in entry.status?.provision?.services
                            if svc.id is mservice.id
                                svc.instance = resp
                                entryData = new Minion entry.id, entry
                                nentry = @minionMgr.minions.update entry.id, entryData
                                return nentry
            else
                return entry

    else
        console.log "qugga-storm isn't installed"
        return entry



Stop = (context, minion, service, type) ->
    if type is 'quagga-clearpath'
        instances = service?.instance
        getPromise()
        .then (resp) ->
            Promise.map context.instances, (instance) =>
                needle.deleteAsync context.baseUrl+ "/quagga/#{instance.name}/#{instance.id}", null
                .then (resp) =>
                    throw new Error name:'invalidStatusCode', value:resp[0].statusCode unless resp[0].statusCode is 204
                    return 'done'
                .catch (err) =>
                    #console.log "quagga-storm.Stop: Failed in deleteAsync ", instance, err
                    throw err

        .catch (resp) =>
                console.log "quagga-storm.Stop: ", resp

        .nodeify (callback)


Update = (context, entry, service, config, type) ->
    if type is 'quagga-clearpath'
        config = config['quagga-clearpath']
        policyConfig = {}
        if config.enable and config.coreConfig
            policyConfig.zebra = config.coreConfig
        if config.protocol.ospf.enable and config.protocol.ospf.config
            policyConfig.ospfd = config.protocol.ospf.config

        service = (svc for svc in entry?.status?.provision?.services when svc.id is service.id)[0]
        instances = service?.instance
        throw new Error name:'missingParams' unless context.instances and context.policyConfig
        for instance in instances
            conf = policyConfig[instance.name]
            throw new Error "Faii to validate the config of #{instance.name}" unless Validate conf, schema[instance.name]
            instance.conf = context.policyConfig[instance.name]

        getPromise()
        .then (resp) =>
            Promise.map context.instances, (instance) =>
                needle.putAsync context.baseUrl+ "/quagga/#{instance.name}/#{instance.id}", instance.conf, json:true
                .then (resp) =>
                    throw new Error 'invalidStatusCode' unless resp[0].statusCode is 200
                    (entry = {})[instance.name] = instance.id
                    return entry
                .catch (err) =>
                    #console.log "quagga-storm.Update: Failed in putAsync ", instance, err
                    throw err

        .then (resp) =>
            #console.log "quagga-storm.Update: resp ", resp
            resp

        .catch (err) =>
            throw err


methods =
    start: Start
    stop: Stop
    update: Update

module.exports.Methods = methods


###
if require.main is module
    context =
        baseUrl: "http://10.0.3.227:5000"
        bInstalledPackages: false
        bFactoryPush: false
        factoryConfig:
            "zebra":
                "password": "zebra"
                "enable-password": "zebra"
                "log-file": "/var/log/zebra.log"
                "line": "vty"
            "ospfd":
                "password": "zebra"
                "enable-password": "zebra"
                "log-file": "/var/log/ospf.log"
                "line": "vty"
        policyConfig:
            "zebra":
                "password": "ospfd"
                "enable-password": "ospfd"
                "log-file": "/var/log/zebra.log"
                "interfaces": [
                    {
                    "name": "wan0"
                    "description": "WAN Link"
                    "link-detect": true
                    }
                ]
                "ip-forwarding": true
                "ip-route": "10.1.1.0/24 172.12.1.5"
                "line": "vty"
            "ospfd":
                "password": "ospfd"
                "enable-password": "ospfd"
                "log-file": "/var/log/ospf.log"
                "iprouting":
                    "interfaces": [
                        {
                            "name": "wan0"
                            "description": "WAN Link"
                        },
                        {
                            "name": "tun4"
                            "description": "link to OSPF router"
                            "ip": [
                                {
                                    "ospfConfig": "network point-to-point"
                                },
                                {
                                    "ospfConfig": "mtu-ignore"
                                }
                            ]
                        }
                        ]
                    "router":
                        "name": "ospf"
                        "default-information": "originate metric 100"
                        "ospf-rid": "3.3.3.3"
                        "networks": [
                            {
                                "ipaddr": "172.12.1.4/30 area 0.0.0.1"
                            }
                            ]
                        "redistribute": [
                            {
                                "redis": "kernel"
                            },
                            {
                                "redis": "connected"
                            },
                            {
                                "redis": "static"
                            }
                        ]
                "line": "vty"


    getPromise()
    .then (resp) =>
        return Start context
    .catch (err) =>
        console.log "Start err ", err
    .then (resp) =>
        console.log "result from Start:\n ", resp
        return Update context
    .catch (err) =>
        console.log "Update err ", err
    .then (resp) =>
        console.log "result from Update:\n ", resp
        return Stop context
    .catch (err) =>
        console.log "Stop err ", err
    .then (resp) =>
        console.log "result from Stop:\n ", resp
    .done
###
