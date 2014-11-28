#= require lib/d3
#= require lib/d3-plugins/topojson
#= require lib/d3-plugins/d3.geo.projection.v0
#= require lib/jquery-2.1.1

reverseOrthographic = (λ, φ) ->
  λ += Math.PI
  cosλ = Math.cos(λ)
  cosφ = Math.cos(φ)
  [cosφ * Math.sin(λ), Math.sin(φ)]

d3.geo.reverseOrthographic = () ->
  d3.geo.projection(reverseOrthographic)


reverseNellHammer = (λ, φ)  ->
  λ *= -1
  [ λ * (1 + Math.cos(φ)) / 2, 2 * (φ - Math.tan(φ / 2)) ];

d3.geo.reverseNellHammer = () ->
  d3.geo.projection(reverseNellHammer)


jQuery ($) ->
  $.vent = $({})
  $.vent.on 'page.ready', ->
    $(".globe").prepare_globes()
