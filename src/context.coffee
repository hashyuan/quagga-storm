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


Validate =  (config) ->
    policyConfig = {}
    if config.enable and config.coreConfig
        policyConfig.zebra = config.coreConfig
    if config.protocol.ospf.enable and config.protocol.ospf.config
        policyConfig.ospfd = config.protocol.ospf.config

    for name, conf of policyConfig
        options = {}
        options.propertyName = name
        res = Validator.validate conf, schema[name], options
        if res.errors?.length
            throw new Error "quagga.Validate ", res


Start =  (context) ->
    throw new Error 'quagga-storm.Start missingParams' unless context.bInstalledPackages and context.service.name

    if context.instances?.length is 2
        return context
    context.instances ?= []
    configObj = context.service.factoryConfig?.config
    config = configObj[context.service.name]
    configs = []
    if config.enable and config.coreConfig
        configs.push {name: 'zebra', config: config.coreConfig}
    if config.protocol.ospf.enable and config.protocol.ospf.config
        configs.push {name: 'ospfd', config: config.protocol.ospf.config}

    getPromise()
    .then (resp) =>
        Promise.map configs, (config) ->
            needle.postAsync context.baseUrl + "/quagga/#{config.name}", config.config, json:true
            .then (resp) =>
                throw new Error 'invalidStatusCode' unless resp[0].statusCode is 200
                return { name: config.name, id: resp[1].id }
            .catch (err) =>
                throw err

        .then (resp) =>
            return resp

        .catch (err) =>
            throw err

    .then (resp) =>
        for res in resp
            if res
                inst = null
                inst = instance for instance in context.instances when instance[res.name]
                if inst
                    inst[res.name] = res.id
                else
                    context.instances.push res
        return context

    .catch (err) =>
        throw err

Stop = (context) ->
    instances = context?.instances
    getPromise()
    .then (resp) ->
        Promise.map instances, (instance) =>
            needle.deleteAsync context.baseUrl+ "/quagga/#{instance.name}/#{instance.id}", null
            .then (resp) =>
                throw new Error name:'invalidStatusCode', value:resp[0].statusCode unless resp[0].statusCode is 204
                return 'done'
            .catch (err) =>
                throw err

    .catch (error) =>
        throw error


Update = (context) ->
    throw new Error name:'quagga-storm.Update missingParams' unless context.instances and context.policyConfig

    policyConfig = {}
    config = context.policyConfig[context.service.name]
    if config.enable and config.coreConfig
        policyConfig.zebra = config.coreConfig
    if config.protocol.ospf.enable and config.protocol.ospf.config
        policyConfig.ospfd = config.protocol.ospf.config

    for instance in context.instances
        conf = policyConfig[instance.name]
        instance.conf = policyConfig[instance.name]

    getPromise()
    .then (resp) =>
        Promise.map context.instances, (instance) =>
            needle.putAsync context.baseUrl+ "/quagga/#{instance.name}/#{instance.id}", instance.conf, json:true
            .then (resp) =>
                throw new Error 'invalidStatusCode' unless resp[0].statusCode is 200
                (entry = {})[instance.name] = instance.id
                return entry
            .catch (err) =>
                throw err

    .then (resp) =>
        resp

    .catch (err) =>
        throw err


module.exports.start = Start
module.exports.stop = Stop
module.exports.update = Update
module.exports.validate = Validate



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
