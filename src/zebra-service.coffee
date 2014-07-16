StormService = require('stormservice')
merge = require('fmerge')
fs = require 'fs'

class zebraService extends StormService

    schema :
        name: "openvpn"
        type: "object"
        additionalProperties: true
        properties:
            hostname:         {"type":"string", "required":true}
            password:         {"type":"string", "required":true}
            'enable password': {"type":"string", "required":true}
            'log file':        {"type":"string", "required":true}
            interfaces:
                type: "array"
                items:
                    name: "interface"
                    type: "object"
                    required: false
                    additionalProperties: true
                    properties:
                        interface: {type:"string", required:true}            
                        description: {type:"string", required:true}
                        'ip address':{type:"string", required:true}
                        'ipv6 address':{type:"string", required:false}
                        bandwidth: {type:"integer", required:true}
            iproutes:
                type: "array"
                items:
                    name: "iproute"
                    type: "object"
                    required: false
                    additionalProperties: true
                    properties:
                        'ip route' : {type:"string", required:false}            
                        

    invocation:
        name: 'zebra'
        path: '/usr/local/sbin'
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
        opts.configPath ?= "/var/stormflash/plugins/zebra"
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

    destructor: ->
        @eliminate()
        #@out.close()
        #@err.close()
        #@emit 'destroy'
module.exports = zebraService
