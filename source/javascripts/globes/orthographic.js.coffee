#= require globes

jQuery ($) ->

  τ = 2 * Math.PI
  rad = Math.PI / 180
  deg = 180
  $.fn.prepare_globes = () ->
    @each ->
      $.globe = new Globe(@)

  class Globe
    ## Prepare container 
    #
    constructor: (element) ->
      $.globe = @
      @_width = $(window).width()
      @_height = $(window).height()

      @_globe_scale = 1 / 3

      @_diameter = (Math.min @_width,@_height) * @_globe_scale
      @_radius = @_diameter / 2
      @_h = 960
      @_w = 960

      @_solstice = new Date(2014,5,21,11,51,0)

      @_days_in_year = 365.242199

      @_milliseconds_in_day = 1000*60*60*24

      @_start_date = Date.now()
      @_play_speed = 10 * 24 * 60

      @_axial_tilt = 23.4

      @_frame_rate = 12

      @_renders = {
        index: null,
        countries: {},
      }

      @_feature_lookup = {}

      # prepare container
      
      @_globe = $(element)

      @_globe_ready = false

      $.getJSON "/data/world.topojson", @prepareGlobe

    ## Build feature set and populate globe
    #
    prepareGlobe: (world) =>
      # prepare a set of projections and translators 
      # that will map data onto display values
      @setAngleFromSummerSolstice()
      lng = @setAngleFromMidday()
      lat = @lat()
      roll = @roll()

      @_background_projection = d3.geo.reverseNellHammer()
        # .clipAngle(70)
        .scale(@_radius)
        .translate([@_width / 2,@_height / 2])
        .precision(.1)

      @_projection = d3.geo.orthographic()
        .clipAngle(90)
        .translate([@_width / 2,@_height / 2])
        .scale(@_radius)
        .rotate([lng,lat,roll])

      @_reverse_projection = d3.geo.reverseOrthographic()
        .clipAngle(90)
        .translate([@_width / 2,@_height / 2])
        .scale(@_radius)
        .rotate([@reverseLng(lng), @reverseLat(lat),@reverseRoll(roll)])

      @_background_path = d3.geo.path()
        .projection(@_background_projection)
      @_path = d3.geo.path()
        .projection(@_projection)
      @_reverse_path = d3.geo.path()
        .projection(@_reverse_projection)

      country_features = topojson.feature(world, world.objects.countries).features
      country_features.forEach (d) =>
        @_feature_lookup[d.id] = d

      @_svg = d3.select(".globe").append("svg")
        .attr("width", @_width)
        .attr("height", @_height)

      defs = @_svg.append("defs")

      defs.append("filter")
        .attr("id", "blur")
      .append("feGaussianBlur")
        .attr("stdDeviation", Math.round(2 * @_globe_scale))

      ocean_fill = defs.append("radialGradient")
        .attr("id", "ocean_fill")
        .attr("cx", "55%")
        .attr("cy", "45%")
      ocean_fill.append("stop").attr("offset", "5%").attr("stop-color", "#ffffff").attr('stop-opacity', "0.5")
      ocean_fill.append("stop").attr("offset", "75%").attr("stop-color", "#ffffff").attr('stop-opacity', "0")
      ocean_fill.append("stop").attr("offset", "100%").attr("stop-color", "#bdbdbd").attr('stop-opacity', "0.2")

      @_sea = @_svg.append("circle")
        .attr("cx", @_width / 2)
        .attr("cy", @_height / 2)
        .attr("r", @_radius)
        .style("fill", "url(#ocean_fill)")

      @_background_country_elements = @_svg.selectAll(".country.background")
        .data(country_features)
        .enter().insert("path")
        .attr("data-code", (d) -> d.id)
        .attr("d", @_background_path)
        .attr("class","country background")

      @_reverse_country_elements = @_svg.selectAll(".country.back")
        .data(country_features)
        .enter().insert("path")
        .attr("data-code", (d) -> d.id)
        .attr("d", @_reverse_path)
        .attr("class","country back")
        .attr("filter", "url(#blur)")

      @_country_elements = @_svg.selectAll(".country.front")
        .data(country_features)
        .enter().insert("path")
        .attr("data-code", (d) -> d.id)
        .attr("d", @_path)
        .attr("class","country front")

      @_globe_pinned = false
      @_globe_ready = true
      @startSpinning()

    render: (template, object) =>
      if object? and object.people? and object.page?
        object.total_records = object.people.length
        if object.total_records > @_per_page + 4
          object.people = object.people.slice((object.page-1) * @_per_page, object.page * @_per_page)
          object.previous_page = object.page - 1 if object.page > 1
          object.next_page = object.page + 1 if object.total_records > object.page * @_per_page
      HandlebarsTemplates[template](object)

    ## Globe manipulation
    #
    startSpinning: () =>
      if @_globe_ready
        @_interval = window.setInterval(@spinStep, 1000 / @_frame_rate)
        @_spinning = true
        # @_globe.on "mouseenter", () =>
        #   @stopSpinning(true)

    stopSpinning: (temporary=false) =>
      if @_interval?
        window.clearInterval(@_interval)
        if temporary and @_spinning
          @_globe.on "mouseleave", @startSpinning
      @_spinning = false

    spinStep: =>
      # [lng, lat, roll] = @_projection.rotate()
      @setAngleFromSummerSolstice()

      lng = @setAngleFromMidday()
      lat = @lat()
      roll = @roll()

      @_projection.rotate([lng,lat,roll])
      @_country_elements.attr("d", @_path)

      @_reverse_projection.rotate([@reverseLng(lng), @reverseLat(lat),@reverseRoll(roll)])
      @_reverse_country_elements.attr("d", @_reverse_path)

      @_background_projection.rotate([@reverseLng(lng), @reverseLat(lat),@reverseRoll(roll)])
      @_background_country_elements.attr("d", @_background_path)

    setAngleFromSummerSolstice: () =>
      date = @getNow()
      @_angle_from_summer_solstice = τ * (date - @_solstice) / @_milliseconds_in_day / @_days_in_year

    setAngleFromMidday: () =>
      date = @getNow()
      @_angle_from_midday = 360 * ((date.getUTCHours() + (date.getUTCMinutes() + (date.getUTCSeconds() / 60)) / 60) / 24 - 0.5)

    reverseLat: (lat) ->
      -lat

    reverseLng: (lng) ->
      lng-180

    reverseRoll: (roll) ->
      -roll

    lat: =>
      - @_axial_tilt * Math.cos(@_angle_from_summer_solstice)

    roll: =>
      @_axial_tilt * Math.sin(@_angle_from_summer_solstice)

    advanceDays: (number_of_days) =>
      number_of_days ?= 1
      @_angle_from_summer_solstice += τ * number_of_days / @_days_in_year
      @_now += number_of_days * @_milliseconds_in_day

    getNow: =>
      if @_play_speed is 1
        new Date()
      else
        new Date(@_start_date + (Date.now() - @_start_date) * @_play_speed)

$ ->
  $.vent.trigger('page.ready')
