define ['d3', 'jquery'], (d3, $) ->
  histogram: () ->
    plotheight: () ->
      @props.height - @props.margin.top - @props.margin.bottom
    plotwidth: () ->
      $(@el).find('.d3').width() - @props.margin.left - @props.margin.right
    create: (el, props, state) ->
      @props = props
      @el = el
      # Initialize svg canvas
      svg = d3.select(el).append('svg')
        .attr('class', 'd3')
        .attr('width', props.width)
        .attr('height', props.height)

      # Make plot group
      data = svg.append('g')
        .attr('class', 'd3-data')
        .attr('transform',
          "translate(#{props.margin.left}, #{props.margin.top})")

      # Append axes placeholders
      data.append('g')
        .attr('class', 'x axis')
        .attr('transform',
          "translate(0, #{@plotheight()})")
      data.append('g')
        .attr('class', 'y axis')
      
      #@update el, state
    update: (el, state) ->
      # Recompute scales
      scales = @scales(state)
      # Render axes
      @axes(el, scales)
      @drawplot(el, scales, state)

    scales: (state) ->
      # xscale 

      # Domains for minutes
      @xdomains = [
        1,
        5,
        10,
        30,
        60,
        60*3,
        60*6,
        60*12,
        60*24,
        60*24*3,
        60*24*7,
        60*24*30,
        60*24*30*3,
        60*24*30*6,
        60*24*30*9,
        60*24*365,
        60*24*365*2,
        60*24*365*3,
        60*24*365*5,
        60*24*365*10,
      ]
      xmax = 0
      if state.data?
        xmax = d3.max(state.data, (d) -> d.time)

      # Find max domain
      maxdomain = @xdomains.length - 1
      @xdomains.some((v, i) =>
        if v > xmax
          maxdomain = i
          return true
        return false
      )
      

      # Gen bins
      #dx = Math.log10(xmax)/@props.bins
      #xdomains = for i in [0..@props.bins]
      #  Math.pow(10, i * dx)
      
      odomains = @xdomains.slice(0,maxdomain + 1)
      xscale = d3.scale.ordinal()
        .rangeBands([0, @plotwidth()])
        .domain(odomains)

      xbins = @xdomains.slice(0, maxdomain)
      xbins.unshift(0)
      xbins.push(9007199254740992)
      
      state.binned_data = d3.layout.histogram()
        .value((d) -> d.time)
        .bins(xbins)(state.data)
      console.log(state.binned_data)

      xscale: xscale
      yscale: d3.scale.linear()
        .range([@plotheight(), 0])
        .domain([0, d3.max(state.binned_data, (d) -> d.y)])

    axes: (el, scales) ->
      # Render axes
      xaxis = d3.svg.axis()
        .scale(scales.xscale)
        .orient('bottom')
        .tickFormat((dv) ->
          fm = d3.format(".0f")
          f = ""
          div = 0
          if dv > 60*24*365 # Years
            div = fm(dv/(60*24*365))
            f = div + "y"
          else if dv > 60*24*30 # Months
            div = fm(dv/(60*24*30))
            f = div + "mo"
          else if dv > 60*24*7 # Weeks
            div = fm(dv/(60*24*7))
            f = div + "w"
          else if dv > 60*24 # Days
            div = fm(dv/(60*24))
            f = div + "d"
          else if dv > 60 # Hours
            div = fm(dv/60)
            f = div + "h"
          else
            f = fm(dv) + "m"
          f
        )
      yaxis = d3.svg.axis()
        .scale(scales.yscale)
        .orient('left')

      xaxisdrawn = d3.select(el).select('g.x.axis')
        .call(xaxis)
        .selectAll('.tick')
        .attr('transform', () ->
          t = @getAttribute('transform')
          m = t.match(/\(([0-9\.]*),([0-9\.]*)\)/)
          p = parseFloat(m[1]) + (scales.xscale.rangeBand() / 2)
          "translate(#{p},#{m[2]})"
        )

      d3.select(el).select('g.y.axis')
        .call(yaxis)

    drawplot: (el,scales,state) ->
      ycalc = (d) => @plotheight() - scales.yscale(d.y)
      nel = d3.select(el).select(".d3-data").selectAll(".bar")
      nel.remove()
      update = nel.data(state.binned_data)
      bars = update.enter().append("g")
        .attr("class", "bar")
        .attr("transform", (d, i) => "translate(" +
          scales.xscale(@xdomains[i]) + "," +
          scales.yscale(d.y) + ")")
      bars.append("rect")
        .attr("x", 1)
        .attr("width", scales.xscale.rangeBand() - 1)
        .attr("height", ycalc)
      bars.append("text")
        .attr("class", (d) =>
          out = ""
          if ycalc(d) < 20
            out = "invert"
          out
        )
        .attr("dy", ".75em")
        .attr("y", (d) =>
          out = 6
          if ycalc(d) < 20
            out = -18
          out
        )
        .attr("x", scales.xscale.rangeBand() / 2)
        .attr("text-anchor", "middle")
        .text((d) -> d3.format(",.0f")(d.y))

