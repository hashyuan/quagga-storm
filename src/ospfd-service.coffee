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
            iprouting:
                name: "ospf routing"
                type: "object"
                required:false
                additionalProperties: true
                properties:
                    interfaces:
                        name: "interfaces"
                        type: "array"
                        items:
                            name: "interface"
                            type: "object"
                            required: false
                            additionalproperties: true
                            properties:
                                name: {type:"string", required:false}
                                description: {type:"string", required:false}
                                ip:
                                    name: "ip"
                                    type: "array"
                                    items:
                                        name: "ospf"
                                        type: "object"
                                        required: false
                                        additionalproperties: true
                                        properties:
                                            ospfConfig: {type:"string", required:false}
                    router:
                        name: "ospf"
                        type: "object"
                        required: false
                        additionalProperties: true
                        properties:
                            name: {type:"string", required:false}
                            'default-information': {type:"string", required:false}
                            'ospf-rid': {type:"string", required:false}
                            networks:
                                name: "networks"
                                type: "array"
                                items:
                                    name: "network"
                                    type: "string"
                                    required:false
                                    additionalproperties: true
                                    properties:
                                        ipaddr: {type:"string", required:false}
                            redistribute:
                                name: "redistribute"
                                type: "array"
                                items:
                                    name: "redis"
                                    type: "string"
                                    required:false
                                    additionalproperties: true
                                    properties:
                                        redis: {type:"string", required:false}

            'line': {"type":"string", "required":false}
            
    invocation:
        name: 'ospfd'
        path: '/sbin'
        monitor: true
        args: []
        options:
            detached: true
            stdio: ["ignore", -1, -1]

    # A function to process arrays and build ospf config
    processArray: (arraykey, value, config) ->
        for objj in value
            for keyyy,valuee of objj
                switch (typeof valuee)
                    when "number", "string"
                        switch keyyy
                            when "name"
                                if arraykey is "interfaces"
                                    config += "interface"+ ' ' + valuee + "\n"
                            when "ipaddr"
                                config += "network"+ ' ' + valuee + "\n"
                            when "redis"
                                config += "redistribute"+ ' ' + valuee + "\n"
                            else
                                config += ' ' + keyyy + ' ' + valuee + "\n"
                    when "boolean"
                        config += ' ' + keyyy + "\n"
        config

    constructor: (id, data, opts) ->
        if data.instance?
            @instance = data.instance
            delete data.instance

        opts ?= {}
        opts.configPath ?= "/var/stormflash/plugins/quagga"
        opts.logPath ?= "/var/log/quagga"

        super id, data, opts

        @configs =
            service:    filename:"#{@configPath}/ospfd_#{@id}.conf"

        @invocation = merge @invocation,
            args: ["--config_file=#{@configs.service.filename}","-d"]
            options: { stdio: ["ignore", @out, @err] }

        @configs.service.generator = (callback) =>
            ospfdconfig = ''
            for key, val of @data
                switch (typeof val)
                    when "object" #routes object
                        for keyy,value of val
                            switch (typeof value)
                                when "object"
                                    if keyy is 'interfaces' #interfaces array
                                        ospfdconfig+= processArray keyy, value, ospfdconfig
                                    else if keyy is 'router' #router object
                                        for keyyy, valuee of value
                                            switch valuee
                                                when "string","number"
                                                    if keyyy is 'name'
                                                        ospfdconfig += "router #{valuee}" + "\n"
                                                    else if keyyy is 'ospf-rid'
                                                        ospfdconfig += ' '+"ospf router-id" + ' ' + valuee + "\n"
                                                when "object" #networks array,redistribute array
                                                    ospfdconfig+= processArray keyy, valuee, ospfdconfig
                    when "number", "string"
                        switch key
                            when "enable-password"
                                ospfdconfig += "enable password" + ' ' + val + "\n"
                            when "log-file"
                                ospfdconfig += "log file" + ' ' + val + "\n"
                            else
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
