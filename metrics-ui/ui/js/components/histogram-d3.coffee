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
      xmin = 1
      xmax = 0
      if state.data?
        xmin = d3.min(state.data, (d) -> d.time)
        xmax = d3.max(state.data, (d) -> d.time)


      # Gen bins
      dx = Math.log10(xmax)/@props.bins
      xbins = for i in [0..@props.bins]
        Math.pow(10, i * dx)
      
      xscale = d3.scale.log()
        .range([0, @plotwidth()])
        .domain([1, xmax])
      
      state.binned_data = d3.layout.histogram()
        .value((d) -> d.time)
        .bins(xbins)(state.data)

      state.binned_data.dx = dx
      xscale: xscale
      yscale: d3.scale.linear()
        .range([@plotheight(), 0])
        .domain([0, d3.max(state.binned_data, (d) -> d.y)])

    axes: (el, scales) ->
      # Render axes
      xaxis = d3.svg.axis()
        .scale(scales.xscale)
        .orient('bottom')
      yaxis = d3.svg.axis()
        .scale(scales.yscale)
        .orient('left')

      xaxisdrawn = d3.select(el).select('g.x.axis')
        .call(xaxis)

      d3.select(el).select('g.y.axis')
        .call(yaxis)

    drawplot: (el,scales,state) ->
      nel = d3.select(el).select(".d3-data").selectAll(".bar")
      update = nel.data(state.binned_data)
      bars = update.enter().append("g")
        .attr("class", "bar")
        .attr("transform", (d) => "translate(" +
          scales.xscale(d.x) + "," +
          scales.yscale(d.y) + ")")
      binwidth = @plotwidth() / @props.bins
      bars.append("rect")
        .attr("x", 1)
        .attr("width", binwidth)
        .attr("height", (d) => @plotheight() - scales.yscale(d.y))
      bars.append("text")
        .attr("dy", ".75em")
        .attr("y", 6)
        .attr("x", binwidth / 2)
        .attr("text-anchor", "middle")
        .text((d) -> d3.format(",.0f")(d.y))

