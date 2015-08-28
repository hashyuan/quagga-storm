StormRegistry = require 'stormregistry'

ZebraService = require './zebra-service'

class zebraRegistry extends StormRegistry
    constructor: (filename) ->
        @on 'load', (key,val) ->
            console.log "restoring #{key} with:",val
            entry = new ZebraService key,val
            if entry?
                entry.saved = true
                @add entry

        @on 'removed', (entry) ->
            # an entry is removed in Registry
            entry.destructor() if entry.destructor?

        super filename

    add: (service) ->
        return unless service instanceof ZebraService
        entry = super service.id, service
        # register for 'running' events of this service and update DB
        entry.on "running", (instance) =>
            if entry.instance isnt instance
                entry.instance = instance
                @update entry

    update: (service) ->
        service.data.instance = service.instance
        super service.id, service
        delete service.data.instance

    get: (key) ->
        entry = super key
        return unless entry?

        if entry.data? and entry.data instanceof ZebraService
            entry.data.id = entry.id
            entry.data
        else
            entry

module.exports  = zebraRegistry
