StormService = require('stormservice')
merge = require('fmerge')
fs = require 'fs'

class ospfdService extends StormService

    schema :
        name: "ospfd"
        type: "object"
        additionalProperties: true
        properties:
            hostname:         {"type":"string", "required":true}
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
            routes:
                name: "router ospf"
                type: "object"
                required: false
                additionalProperties: true
                properties:
                    networks:
                        name: "networks"
                        type: "array"
                        items:
                            name: "network"
                            type: "string"
                            required:false
                    'default-information': {type:"string", required:false}
            'line': {"type":"string", "required":false}
            
    invocation:
        name: 'ospfd'
        path: '/bin'
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
        opts.logPath ?= "/var/log/ospfd"

        super id, data, opts

        @configs =
            service:    filename:"#{@configPath}/ospfd_#{@id}.conf"

        @invocation = merge @invocation,
            args: ["--config_file", "#{@configs.service.filename}","-d"]
            options: { stdio: ["ignore", @out, @err] }

        @configs.service.generator = (callback) =>
            ospfdconfig = ''
            for key, val of @data
                switch (typeof val)
                    #router object
                    when "object"
                        for keyy,value of val
                            switch (typeof value)
                                #router ospf
                                when "string","number"
                                    ospfdconfig += keyy + ' ' + value + "\n"
                                #network 
                                when "object"
                                    #array
                                    for objj in value
                                        for keyyy,valuee of objj
                                            ospfdconfig += keyyy + ' ' + valuee + "\n"
                    when "number", "string"
                        ospfdconfig += key + ' ' + val + "\n"
                    when "boolean"
                        ospfdconfig += key + "\n"
            callback ospfdconfig

    getconfig: ->
        return @configs
    getinvocation: ->
        return @invocation

    destructor: ->
        @eliminate()
        #@out.close()
        #@err.close()
        #@emit 'destroy'
module.exports = ospfdService
