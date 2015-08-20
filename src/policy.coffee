assert = require 'assert'
Promise = require 'bluebird'
async = require 'async'
needle = Promise.promisifyAll(require('needle'))

validateUUID = (data, opts) ->
    validator = require 'validator'
    return validator.isUUID(data)

validatePort = (data, opts) ->
    return false if  data > 65536 or data < 0
    match = opts.rules?.filter (rule) ->
        return true if rule is data
    return false if match?.len > 0 and opts.rules?.len > 0
    return true

validateProtocol = (data, rules) ->
    match = opts.rules?.filter (rule) ->
        return true if data is rule
    return true if match.len > 0
    return false

validateString = (data, rules) ->
    return true

validateMaps =
    "type:uuid": validateUUID
    "type:port": validatePort
    "type:string": validateString
    "type:protocol": validateProtocol

getPromise = ->
    return new Promise (resolve, reject) ->
        resolve()

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

Validate =  (obj, schema, callback) ->
    console.log "In Validate done"
    return true


CheckPackages = (baseUrl) ->
    pkgs = require('../package.json').stormflash.packages
    packages = []
    for pkg in pkgs
        pack =
            name: pkg.split("://")[1]
            version: '*'
            source:pkg.split("://")[0]+"://"
        packages.push pack
    plugin =
        name:require('../package.json').name
        version:require('../package.json').version
        source:"npm://"
    packages.push  plugin
    
    needle.getAsync baseUrl+'/packages'
    .then (resp) =>
        console.log "resp[1] ", resp[1]
        return resp[1]
    .then (rpkgs) =>
        rpkgs?.filter (rpkg) =>
            packages = packages.filter (pkg) =>
                return true if not (pkg.name is rpkg.name and (rpkg.source is 'builtin' or rpkg.source is pkg.source) and (pkg.version is "*" or pkg.version is rpkg.version))

        return packages


Start =  (context, callback) ->
    getPromise()
    .then (resp) ->
        return Verify context
    .then (resp) =>
        console.log "quagga-storm.Start: Verify ", resp
        if resp
            Configs = []
            for name, config of context.factoryConfig
                if Validate config, schema[name]
                    Configs.push {name: name, config: config}

            unless context.bFactoryPush
                Promise.map Configs, (Config) ->
                    needle.postAsync context.baseUrl+ "/quagga/#{Config.name}", Config.config, json:true
                    .then (resp) =>
                        throw new Error 'invalidStatusCode' unless resp[0].statusCode is 200
                        return { name: Config.name, id: resp[1].id }
                    .catch (err) =>
                        console.log "quagga-storm.Start: Failed in postAsync ", Config, err
                        throw new Error err

                .then (resp) =>
                    #console.log "quagga-storm.Start: resp ", resp
                    context.instances = resp
                    context.bFactoryPush = true
                    return resp
        else
            return []

    .nodeify (callback)


Stop = (context, callback) ->
    getPromise()
    .then (resp) ->
        Promise.map context.instances, (instance) =>
            needle.deleteAsync context.baseUrl+"/quagga/#{instance.name}/#{instance.id}"
                .then (resp) =>
                    throw new Error name:'invalidStatusCode', value:resp[0].statusCode unless resp[0].statusCode is 204
                    return resp[1]
                .catch (err) ->
                    console.log "quagga-storm.Stop: Failed in deleteAsync ", instance, err
                    throw new Error err

        .then (resp) =>
            #console.log "quagga-storm.Stop: resp ", resp
            context.instances = []

    .nodeify (callback)

Update = (context, callback) ->
    throw new Error name:'missingParams' unless context?.instances and context?.policyConfig
    for instance in context.instances
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
                console.log "quagga-storm.Update: Failed in putAsync ", instance, err
                throw new Error err

    .then (resp) =>
        #console.log "quagga-storm.Update: resp ", resp
        return resp

    .nodeify (callback)

Verify = (context, callback) ->
    unless context.bInstalledPackages
        Promise.try =>
            return CheckPackages context.baseUrl

        .then (packs) =>
            return true unless packs?.length
    else
        return true

methods =
    Start: Start
    Stop: Stop
    Update: Update
    Validate: Validate
    Verify: Verify

module.exports.methods = methods



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
                "line": "vty"
            "ospfd":
                "password": "ospfd"
                "enable-password": "ospfd"
                "log-file": "/var/log/ospf.log"
                "line": "vty"

    getPromise()
    .then (resp) =>
        return Start context
    .then (resp) =>
        console.log "result from Start ", resp
        return Update context
    .then (resp) =>
        console.log "result from Update ", resp
        return Stop context
    .then (resp) =>
        console.log "result from Stop ", resp
