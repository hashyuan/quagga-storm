ZebraService = require './zebra-service'
ZebraRegistry = require './zebra-registry'
OspfdService = require './ospfd-service'
OspfdRegistry = require './ospfd-registry'
###
RipdService = require './ripd-service'
RipdRegistry = require './ripd-registry'
BgpdService = require './bgpd-service'
BgpdRegistry = require './bgpd-registry'
###

async = require('async')

#oservice = null
#zservice = null

@include = ->
    agent = @settings.agent
    unless agent?
        throw  new Error "this plugin requires to be running in the context of a valid StormAgent!"

    plugindir = @settings.plugindir
    plugindir ?= "/var/stormflash/plugins/zebra"

    # Zebra routine
    zregistry = new ZebraRegistry plugindir+"/zebra.db"
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
    oregistry = new OspfdRegistry plugindir+"/ospfd.db"
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
    ###
    #ripd routine
    rregistry = new RipdRegistry plugindir+"/Ripd.db"    
    rregistry.on 'ready', ->
        for service in @list()
            continue unless service instanceof RipdService

            agent.log "restore: trying to recover:", service
            do (service) -> service.generate (err) ->
                if err?
                    return agent.log "restore: Ripd #{service.id} failed to generate configs!"
                agent.invoke service, (err, instance) ->
                    if err?
                        agent.log "restore: Ripd #{service.id} invoke failed with:", err
                    else
                        agent.log "restore: Ripd #{service.id} invoke succeeded wtih #{instance}"

    #bgpd routine
    bregistry = new BgpdRegistry plugindir+"/Bgpd.db"    
    bregistry.on 'ready', ->
        for service in @list()
            continue unless service instanceof BgpdService

            agent.log "restore: trying to recover:", service
            do (service) -> service.generate (err) ->
                if err?
                    return agent.log "restore: Bgpd #{service.id} failed to generate configs!"
                agent.invoke service, (err, instance) ->
                    if err?
                        agent.log "restore: Bgpd #{service.id} invoke failed with:", err
                    else
                        agent.log "restore: Bgpd #{service.id} invoke succeeded wtih #{instance}"
    ###


    #CRUD Endpoints related to zebra daemon
    @post '/quagga/zebra': ->
        try
            zservice = new ZebraService null, @body, configPath:'/var/stormflash/plugins/zebra',logPath: '/var/log/zebra'
        catch err
            return @next err
            
        zservice.generate (err, results) =>
            return @next err if err?
            agent.log "POST /Zebra generation results :" +  JSON.stringify results
            zregistry.add zservice
            agent.invoke zservice, (err, instance) =>
                if err?
                    zregistry.remove zservice.id
                    return @next err
                else
                    @send {id: zservice.id, running: true}


    @get '/quagga/zebra': ->
        @send zregistry.list()

    @get '/quagga/zebra/:id': ->
        service = zregistry.get @params.id
        unless service?
            @send 404
        else
            @send service

    @put '/quagga/zebra/:id': ->
        service = zregistry.get @params.id
        return @send 404 unless service?

        # when a service is CHANGED, it emits "ready"
        service.updateZebra @body, (err, results) =>
            return @next err if err?
            agent.log "service.updateZebra:", results
            @send { updated: true }

    @del '/quagga/zebra/:id': ->
        service = zregistry.get @params.id
        return @send 404 unless service?

        zregistry.remove @params.id
        @send 204


    #CRUD Endpoints related to ospf daemon
    @post '/quagga/ospfd': ->
        try
            oservice = new OspfdService null, @body, configPath:'/var/stormflash/plugins/ospf',logPath: '/var/log/ospf'
        catch err
            return @next err
            
        oservice.generate (err, results) =>
            return @next err if err?
            agent.log "POST /ospfd generation results :" +  JSON.stringify results
            oregistry.add oservice
            agent.invoke oservice, (err, instance) =>
                if err?
                    oregistry.remove oservice.id
                    return @next err
                else
                    @send {id: oservice.id, running: true}


    @get '/quagga/ospfd': ->
        @send oregistry.list()

    @get '/quagga/ospfd/:id': ->
        service = oregistry.get @params.id
        unless service?
            @send 404
        else
            @send service

    @put '/quagga/ospfd/:id': ->
        service = oregistry.get @params.id
        return @send 404 unless service?

        # when a service is CHANGED, it emits "ready"
        service.updateOspf @body, (err, results) =>
            return @next err if err?
            agent.log "service.updateOspf:", results
            @send { updated: true }

    @del '/quagga/ospfd/:id': ->
        service = oregistry.get @params.id
        return @send 404 unless service?

        oregistry.remove @params.id
        @send 204


    ###
    @post '/quagga/ripd': ->
        try
            rservice = new RipdService null, @body, {}
        catch err
            return @next err
            
        rservice.generate (err, results) =>
            return @next err if err?
            agent.log "POST /ripd generation resultis :" +  JSON.stringify results
            rregistry.add rservice
            agent.invoke rservice, (err, instance) =>
                if err?
                    #serverRegistry.remove service.id
                    return @next err
                else
                    @send {id: rservice.id, running: true}

    @post '/quagga/bgpd': ->
        try
            bservice = new BgpdService null, @body, {}
        catch err
            return @next err
            
        bservice.generate (err, results) =>
            return @next err if err?
            agent.log "POST /quagga/bgpd generation result  : " +  JSON.stringify results
            bregistry.add bservice
            agent.invoke bservice, (err, instance) =>
                if err?
                    #serverRegistry.remove service.id
                    return @next err
                else
                    @send {id: bservice.id, running: true}


    @get '/quagga/zebra/config': ->
        @send zservice.getconfig()

    @get '/quagga/zebra/invocation': ->
        @send zservice.getinvocation()

    @get '/quagga/ospfd/config': ->
        @send oservice.getconfig()

    @get '/quagga/ospfd/invocation': ->
        @send oservice.getinvocation()
    ###
