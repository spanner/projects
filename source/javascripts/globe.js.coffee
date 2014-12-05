#= require lib/d3
#= require lib/d3-plugins/topojson
#= require lib/d3-plugins/d3.geo.projection.v0

τ = 2 * Math.PI
rad = Math.PI / 180
deg = 180

d3.geo.reverseOrthographic = () ->
  d3.geo.projection (λ, φ) ->
    λ += Math.PI
    [Math.cos(φ) * Math.sin(λ), Math.sin(φ)]

d3.geo.reverseNellHammer = () ->
  d3.geo.projection (λ, φ)  ->
    λ *= -1
    [λ * (1 + Math.cos(φ)) / 2, 2 * (φ - Math.tan(φ / 2))]

class Globe
  ## Prepare container 
  #
  constructor: () ->
    @_w = window.innerWidth
    @_h = window.innerHeight

    @_globe_scale = 2 / 3
    @_diameter = (Math.min @_w, @_h) * @_globe_scale
    @_radius = @_diameter / 2
    @_frame_rate = 24

    @_background_projection = d3.geo.reverseNellHammer()
      .scale(@_radius)
      .translate([@_w / 2, @_h / 2])
      .precision(.1)

    @_projection = d3.geo.orthographic()
      .clipAngle(90)
      .translate([@_w / 2, @_h / 2])
      .scale(@_radius)
      .rotate([0, 0, 0])

    @_background_path = d3.geo.path()
      .projection(@_background_projection)

    @_path = d3.geo.path()
      .projection(@_projection)

    @_svg = d3.select("#globe").append("svg")
      .attr("width", @_w)
      .attr("height", @_h)

    defs = @_svg.append("defs")
    ocean_fill = defs.append("radialGradient")
      .attr("id", "ocean_fill")
      .attr("cx", "52%")
      .attr("cy", "48%")
    ocean_fill.append("stop").attr("offset", "5%").attr("stop-color", "#ffffff").attr('stop-opacity', "0.9")
    ocean_fill.append("stop").attr("offset", "85%").attr("stop-color", "#ffffff").attr('stop-opacity', "0.75")
    ocean_fill.append("stop").attr("offset", "100%").attr("stop-color", "#bdbdbd").attr('stop-opacity', "0.6")

    land_fill = defs.append("radialGradient")
      .attr("id", "land_fill")
      .attr("cx", "52%")
      .attr("cy", "48%")
    land_fill.append("stop").attr("offset", "5%").attr("stop-color", "#46594b").attr('stop-opacity', "0.45")
    land_fill.append("stop").attr("offset", "100%").attr("stop-color", "#46594b").attr('stop-opacity', "1.0")

    d3.json "/data/world.topojson", @displayCountries
    d3.json "/data/ip_lat_lngs.json", @displayLocations


  ## Build feature set and populate globe
  #
  displayCountries: (error, world) =>

    # prepare a set of projections and translators 
    # that will map data onto display values

    country_features = topojson.feature(world, world.objects.countries)

    @_background_country_elements = @_svg.append("path")
      .datum(country_features)
      .attr("data-code", (d) -> d.id)
      .attr("d", @_background_path)
      .attr("class","country background")

    @_sea = @_svg.append("circle")
      .attr("cx", @_w / 2)
      .attr("cy", @_h / 2)
      .attr("r", @_radius)
      .style("fill", "url(#ocean_fill)")

    @_country_elements = @_svg.append("path")
      .datum(country_features)
      .attr("d", @_path)
      .attr("class","country front")
      .style("fill", "url(#land_fill)")

    window.setInterval @spinStep, 1000 / @_frame_rate

  displayLocations: (error, points) =>
    points = points.slice 0, 500
    circles = points.map ({lat:lat,lng:lng}={}) ->
      d3.geo.circle().origin([lng,lat]).angle(1.0)()

    multi_circles =
      type: "MultiPolygon"
      coordinates: circles.map (poly) -> poly.coordinates

    @_locations = @_svg.append('path')
      .datum(multi_circles)
      .attr("class","location")
      .attr("d", @_path)

    # @_locations = @_svg.selectAll('path')
    #   .data(circles)
    #   .enter().insert("path")
    #   .attr("class","location")
    #   .attr("d", @_path)

  spinStep: =>
    [lng, lat, roll] = @_projection.rotate()
    lng = lng + 0.33
    @_projection.rotate([lng ,lat,roll])
    @_background_projection.rotate([lng-180, -lat, -roll])
    @_country_elements?.attr("d", @_path)
    @_background_country_elements?.attr("d", @_background_path)
    @_locations?.attr("d", @_path)


window.globe = new Globe()
