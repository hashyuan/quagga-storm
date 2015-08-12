StormService = require('stormservice')
merge = require('fmerge')
fs = require 'fs'

class ospfdService extends StormService

    schema :
        name: "ospfd"
        type: "object"
        additionalProperties: false
        properties:
            hostname:         {"type":"string", "required":false}
            password:         {"type":"string", "required":true}
            'enable-password': {"type":"string", "required":false}
            'log-file':        {"type":"string", "required":false}
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
            
    invocation:
        name: 'ospfd'
        path: '/sbin'
        monitor: true
        args: []
        options:
            detached: true
            stdio: ["ignore", -1, -1]

    # A function to process arrays and build ospf config
    processArray: (arraykey, value) ->
        config = ''
        for objj in value
            for keyyy,valuee of objj
                switch (typeof valuee)
                    when "number", "string"
                        switch keyyy
                            when "name"
                                if arraykey is "interfaces"
                                    config += "interface"+ ' ' + valuee + "\n"
                            when "ipaddr"
                                config += ' '+ "network"+ ' ' + valuee + "\n"
                            when "redis"
                                config += ' '+ "redistribute"+ ' ' + valuee + "\n"
                            else
                                config += ' ' + keyyy + ' ' + valuee + "\n"
                    when "object"
                        for objjj in valuee
                            for keyyyy,valueee of objjj
                                switch (typeof valueee)
                                    when "number", "string"
                                        if keyyy is "ip"
                                            config += ' '+ "ip ospf"+ ' ' + valueee + "\n"
                                    when "boolean"
                                        if valueee is true
                                            config += ' ' + keyyyy + "\n"
                    when "boolean"
                        if valuee is true
                            config += ' ' + keyyy + "\n"
        config

    constructor: (id, data, opts) ->
        if data.instance?
            @instance = data.instance
            delete data.instance

        opts ?= {}
        opts.configPath ?= "/var/stormflash/plugins/ospf"
        opts.logPath ?= "/var/log/ospf"

        super id, data, opts

        @configs =
            service:    filename:"#{@configPath}/ospfd_#{@id}.conf"

        @invocation = merge @invocation,
            args: ["--config_file=#{@configs.service.filename}"]
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
                                        ospfdconfig+= @processArray keyy, value
                                    else if keyy is 'router' #router object
                                        for keyyy, valuee of value
                                            switch (typeof valuee)
                                                when "string","number"
                                                    if keyyy is 'name'
                                                        ospfdconfig += "router #{valuee}" + "\n"
                                                    else if keyyy is 'ospf-rid'
                                                        ospfdconfig += ' ' + "ospf router-id" + ' ' + valuee + "\n"
                                                    else
                                                        ospfdconfig += ' ' + keyyy + ' ' + valuee + "\n"
                                                when "object" #networks array,redistribute array
                                                    ospfdconfig+= @processArray keyy, valuee
                    when "number", "string"
                        switch key
                            when "enable-password"
                                ospfdconfig += "enable password" + ' ' + val + "\n"
                            when "log-file"
                                ospfdconfig += "log file" + ' ' + val + "\n"
                            else
                                ospfdconfig += key + ' ' + val + "\n"
                    when "boolean"
                        if val is true
                            ospfdconfig += key + "\n"

            callback ospfdconfig

    updateOspf: (newconfig, callback) ->
        @data = newconfig
        @generate 'service', callback

    ###
    getconfig: ->
        return @configs
    getinvocation: ->
        return @invocation
    ###
        
    destructor: ->
        @eliminate()
        #@out.close()
        #@err.close()
        #@emit 'destroy'
        
module.exports = ospfdService
