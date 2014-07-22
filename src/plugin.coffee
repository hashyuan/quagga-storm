ZebraService = require './zebra-service'
ZebraRegistry = require './zebra-registry'
OspfdService = require './ospfd-service'
OspfdRegistry = require './ospfd-registry'

async = require('async')

oservice = null
zservice = null

@include = ->
    agent = @settings.agent
    unless agent?
        throw  new Error "this plugin requires to be running in the context of a valid StormAgent!"

    plugindir = @settings.plugindir
    plugindir ?= "/var/stormflash/plugins/zebra"

    # Zebra routine
    zregistry = new ZebraRegistry plugindir+"/Zebra.db"    
    zregistry.on 'ready', ->
        for service in @list()
            continue unless service instanceof ZebraService

            agent.log "restore: trying to recover:", service
            do (service) -> service.generate (err) ->
                if err?
                    return agent.log "restore: Zebra #{service.id} failed to generate configs!"
                agent.invoke service, (err, instance) ->
                    if err?
                        agent.log "restore: Zebra #{service.id} invoke failed with:", err
                    else
                        agent.log "restore: Zebra #{service.id} invoke succeeded wtih #{instance}"

    #ospfd routine
    oregistry = new OspfdRegistry plugindir+"/Ospfd.db"    
    oregistry.on 'ready', ->
        for service in @list()
            continue unless service instanceof OspfdService

            agent.log "restore: trying to recover:", service
            do (service) -> service.generate (err) ->
                if err?
                    return agent.log "restore: Ospfd #{service.id} failed to generate configs!"
                agent.invoke service, (err, instance) ->
                    if err?
                        agent.log "restore: Ospfd #{service.id} invoke failed with:", err
                    else
                        agent.log "restore: Ospfd #{service.id} invoke succeeded wtih #{instance}"


    @post '/quagga/zebra': ->
        try
            zservice = new ZebraService null, @body, {}
        catch err
            return @next err
            
        zservice.generate (err, results) =>
            return @next err if err?
            agent.log "POST /Zebra generation resultis suresh :" +  JSON.stringify results
            zregistry.add zservice
            agent.invoke zservice, (err, instance) =>
                if err?
                    #serverRegistry.remove service.id
                    return @next err
                else
                    @send {id: zservice.id, running: true}

    @get '/quagga/zebra/config': ->
        @send zservice.getconfig()

    @get '/quagga/zebra/invocation': ->
        @send zservice.getinvocation()

    @get '/quagga/ospfd/config': ->
        @send oservice.getconfig()

    @get '/quagga/ospfd/invocation': ->
        @send oservice.getinvocation()

    @post '/quagga/ospfd': ->
        try
            oservice = new OspfdService null, @body, {}
        catch err
            return @next err
            
        oservice.generate (err, results) =>
            return @next err if err?
            agent.log "POST /ospfd generation resultis suresh :" +  JSON.stringify results
            oregistry.add oservice
            agent.invoke oservice, (err, instance) =>
                if err?
                    #serverRegistry.remove service.id
                    return @next err
                else
                    @send {id: oservice.id, running: true}

