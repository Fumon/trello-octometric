define ['d3'], (d3) ->
  plotheight: () ->
    @props.height - @props.margin.top - @props.margin.bottom
  plotwidth: () ->
    @props.width - @props.margin.left - @props.margin.right
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
      .attr('class', '.d3-data')
      .attr('transform',
        "translate(#{props.margin.left}, #{props.margin.top})")

    # Make plotline placeholder
    data.append('path')
      .attr('class', 'line')

    # Append axes placeholders
    data.append('g')
      .attr('class', 'x axis')
      .attr('transform',
        "translate(0, #{@plotheight()})")
    data.append('g')
      .attr('class', 'y axis')
    
    @update el, state
  update: (el, state) ->
    # Recompute scales
    scales = @scales(state)
    # Render axes
    @axes(el, scales)
    @drawplot(el, scales, state)

  scales: (state) ->
    xscale: d3.scale.ordinal()
      .rangePoints([@plotwidth(), 0])
      .domain(state.data.map (d) -> "#{d.day}")
    yscale: d3.scale.linear()
      .range([@plotheight(), 0])
      .domain([90, d3.max(state.data, (d) -> d.end_of_day_total) + 20])

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

    xaxisdrawn.selectAll('text')
      .style('text-anchor', 'end')
      .attr('transform', 'rotate(-65)')
    d3.select(el).select('g.y.axis')
      .call(yaxis)

  drawplot: (el,scales,state) ->
    # Create a line function
    lfunc = d3.svg.line()
      .x((d) => scales.xscale("#{d.day}"))
      .y((d) => scales.yscale(d.end_of_day_total))
      .interpolate('linear')

    # Draw to plot
    d3.select(el).select('path.line')
      .attr('d', lfunc(state.data))
