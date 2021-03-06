######################################################
# AnnotationSelector widget
# the annotationSelector makes an annotated word interactive
# This widget is instantiated by the IKS.annotate widget for the 
# text enhancements and RDFa annotated elements.######################################################
jQuery.widget "IKS.annotationInteraction",
    # just for debugging and understanding
    __widgetName: "IKS.annotationInteraction"
    options:
        ns:
            dbpedia:  "http://dbpedia.org/ontology/"
            skos:     "http://www.w3.org/2004/02/skos/core#"
        getTypes: ->
            [
                uri:   "#{@ns.dbpedia}Place"
                label: 'Place'
            ,
                uri:   "#{@ns.dbpedia}Person"
                label: 'Person'
            ,
                uri:   "#{@ns.dbpedia}Organisation"
                label: 'Organisation'
            ,
                uri:   "#{@ns.skos}Concept"
                label: 'Concept'
            ]
        getSources: ->
            [
                uri: "http://dbpedia.org/resource/"
                label: "dbpedia"
            ,
                uri: "http://sws.geonames.org/"
                label: "geonames"
            ]

    _create: ->
        @_logger = if @options.debug then console else 
            info: ->
            warn: ->
            error: ->
            log: ->
        @vie = @options.vie
        @_loadEntity (entity) =>
            @entity = entity
            @_initTooltip()
    _destroy: ->
        @element.tooltip 'destroy'

    _initTooltip: ->
        widget = @
        @_logger.info "init tooltip for", @element
        if @options.showTooltip
            jQuery(@element).tooltip
                items: "[about]"
                hide: 
                    effect: "hide"
                    delay: 50
                show:
                    effect: "show"
                    delay: 50
                content: (response) =>
                    uri = @element.attr "about"
                    @_logger.info "tooltip uri:", uri
                    widget._createPreview uri
    _createPreview: (uri) ->
        html = ""
        picSize = 100
        depictionUrl = @_getDepiction @entity, picSize
        if depictionUrl
            html += "<img style='float:left;padding: 5px;width: #{picSize}px' src='#{depictionUrl.substring 1, depictionUrl.length-1}'/>"
        descr = @_getDescription @entity
        unless descr
            @_logger.warn "No description found for", @entity
            descr = "No description found."
        html += "<div style='padding 5px;width:250px;float:left;'><small>#{descr}</small></div>"
        @_logger.info "tooltip for #{uri}: cacheEntry loaded", @entity
        html

    _loadEntity: (callback) ->
        @vie.use new @vie.RdfaService()
        @vie.load
            element: @element
        .using("rdfa")
        .execute()
        .success (res) =>
            @_logger.info "found", res, @element, @vie
            _(res).each (entity) =>
                @vie.load
                    entity: entity.getSubject()
                .using("stanbol")
                .execute()
                .success (res) =>
                    loadedEntity = _(res).detect (e) ->
                        entity.getSubject() is e.getSubject()
                    callback loadedEntity
                .fail (err) =>
                    @_logger.error "error getting entity from stanbol", err, entity.getSubject()
        .fail (f) =>
            @_logger.error "error reading RDFa", f, @element

    _getUserLang: ->
        navigatorLanguage = window.navigator.language || window.navigator.userLanguage
        navigatorLanguage.split("-")[0]
    _getDepiction: (entity, picSize) ->
        preferredFields = @options.depictionProperties
        # field is the first property name with a value
        field = _(preferredFields).detect (field) ->
            true if entity.get field
        # fieldValue is an array of at least one value
        if field && fieldValue = _([entity.get field]).flatten()
            # 
            depictionUrl = _(fieldValue).detect (uri) ->
                uri = uri.getSubject?() or uri
                true if uri.indexOf("thumb") isnt -1
            .replace /[0-9]{2..3}px/, "#{picSize}px"
            depictionUrl

    _getLabel: (entity) ->
        preferredFields = @options.labelProperties
        preferredLanguages = [@_getUserLang(), @options.fallbackLanguage]
        @_getPreferredLangForPreferredProperty entity, preferredFields, preferredLanguages

    _getDescription: (entity) ->
        preferredFields = @options.descriptionProperties
        preferredLanguages = [@_getUserLang(), @options.fallbackLanguage]
        @_getPreferredLangForPreferredProperty entity, preferredFields, preferredLanguages

    _getPreferredLangForPreferredProperty: (entity, preferredFields, preferredLanguages) ->
        # Try to find a label in the preferred language
        for lang in preferredLanguages
            for property in preferredFields
                # property can be a string e.g. "skos:prefLabel"
                if typeof property is "string" and entity.get property
                    labelArr = _.flatten [entity.get property]
                    # select the label in the user's language
                    label = _(labelArr).detect (label) =>
                        # for compatibility with stanbol before 0.9
                        true if typeof label is "string" and label.toString().indexOf("@#{lang}") > -1
                        true if typeof label is "object" and label["@language"] is lang
                    if label
                        return label
                        .toString()
                        # for compatibility with stanbol before 0.9
                        .replace /(^\"*|\"*@..$)/g, ""
                # property can be an object like {property: "skos:broader", makeLabel: function(propertyValueArr){return "..."}}
                else if typeof property is "object" and entity.get property.property
                    valueArr = _.flatten [entity.get property.property]
                    valueArr = _(valueArr).map (termUri) ->
                        if termUri.isEntity then termUri.getSubject() else termUri
                    return property.makeLabel valueArr
        ""

