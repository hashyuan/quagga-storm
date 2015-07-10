StormService = require('stormservice')
merge = require('fmerge')
fs = require 'fs'

class zebraService extends StormService

    schema :
        name: "zebra"
        type: "object"
        required: true
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
                    type: "object"
                    required: false
                    additionalProperties: true
                    properties:
                        name: {type:"string",required:"false"}
                        description: {type:"string", required:false}
                        'link-detect':       {"type":"boolean", "required":false}
                        'ip-address':        {"type":"string", "required":false}
            'ip-route':        {"type":"string", "required":false}
            'ip-forwarding':   {"type":"boolean", "required":false}
            'ipv6-forwarding':   {"type":"boolean", "required":false}
            'line':        {"type":"string", "required":false}

    invocation:
        name: 'zebra'
        path: '/sbin'
        monitor: true
        args: []
        options:
            detached: true
            stdio: ["ignore", -1, -1]

    # A function to process arrays and build ospf config
    processArray: (arraykey, value, config) ->

        for obj in value
            for key,valuee of obj
                switch (typeof valuee)
                    when "number", "string"
                        switch key
                            when "name"
                                if arraykey is "interfaces"
                                    config += "interface"+ ' ' + valuee + "\n"
                            when "ip-address"
                                config += ' ' + "ip address" + ' ' + valuee + "\n"
                            else
                                config += ' ' + key + ' ' + valuee + "\n"
                    when "boolean"
                        config += ' ' + key + "\n"
        config


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
            args: ["--config_file=#{@configs.service.filename}","-d"]
            options: { stdio: ["ignore", @out, @err] }

        @configs.service.generator = (callback) =>
            zebraconfig = ''
            for key, val of @data
                switch (typeof val)
                    when "object"
                        zebraconfig+= processArray key, val, zebraconfig
                    when "number", "string"
                        switch key
                            when "enable-password"
                                zebraconfig += "enable password" + ' ' + val + "\n"
                            when "log-file"
                                zebraconfig += "log file" + ' ' + val + "\n"
                            when "ip-route"
                                zebraconfig += "ip route" + ' ' + val + "\n"
                            else
                                zebraconfig += key + ' ' + val + "\n"
                    when "boolean"
                        switch key
                            when "ip-forwarding"
                                zebraconfig += "ip forwarding" + "\n"
                            when "ipv6-forwarding"
                                zebraconfig += "ipv6 forwarding" + "\n"
            callback zebraconfig

    updateZebra: (zebraconfig, callback) ->
        @data = zebraconfig
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

module.exports = zebraService
