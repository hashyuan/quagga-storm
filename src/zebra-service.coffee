StormService = require('stormservice')
merge = require('fmerge')
fs = require 'fs'

class zebraService extends StormService

    schema :
        name: "zebra"
        type: "object"
        additionalProperties: true
        properties:
            hostname:         {"type":"string", "required":false}
            password:         {"type":"string", "required":true}
            'enable-password': {"type":"string", "required":false}
            'log-file':        {"type":"string", "required":false}
            interfaces:
                name: "interfaces"
                type: "array"
                items:
                    name: "interface"
                    type: "object"
                    required: false
                    additionalProperties: true
                    properties:
                        description: {type:"string", required:false}
                        'link-detect':       {"type":"boolean", "required":false}
                        'ip-address':        {"type":"string", "required":false}
            'ip-route':        {"type":"string", "required":false}
            'ip-forwarding':   {"type":"boolean", "required":false}
            'ipv6-forwarding':   {"type":"boolean", "required":false}

    invocation:
        name: 'zebra'
        path: '/sbin'
        monitor: true
        args: []
        options:
            detached: true
            stdio: ["ignore", -1, -1]

    constructor: (id, data, opts) ->
        if data.instance?
            @instance = data.instance
            delete data.instance

        opts ?= {}
        opts.configPath ?= "/var/stormflash/plugins/quagga"
        opts.logPath ?= "/var/log/zebra"

        super id, data, opts

        @configs =
            service:    filename:"#{@configPath}/zebra_#{@id}.conf"

        @invocation = merge @invocation,
            args: ["--config_file", "#{@configs.service.filename}","-d"]
            options: { stdio: ["ignore", @out, @err] }

        @configs.service.generator = (callback) =>
            zebraconfig = ''
            for key, val of @data
                switch (typeof val)
                    when "object"
                        for obj in val
                            console.log "obj is " + obj	
                            for keyy,value of obj
                                console.log "keyy , value " + keyy
                                zebraconfig += keyy + ' ' + value + "\n"
                    when "number", "string"
                        zebraconfig += key + ' ' + val + "\n"
                    when "boolean"
                        zebraconfig += key + "\n"
            callback zebraconfig
    getconfig: ->
        return @configs
    getinvocation: ->
        return @invocation

    destructor: ->
        @eliminate()
        #@out.close()
        #@err.close()
        #@emit 'destroy'
module.exports = zebraService
