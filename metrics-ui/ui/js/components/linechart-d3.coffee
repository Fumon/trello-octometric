define ['d3', 'jquery'], (d3, $) ->
  linechart: () ->
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
        .attr('class', '.d3-data')
        .attr('transform',
          "translate(#{props.margin.left}, #{props.margin.top})")

      # Make plotline placeholder
      for names, i in @props.datanames
        data.append('path')
          .attr('class', "line#{i}")

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
      # xscale 
      xmin = 0
      xmax = 0
      if state.data.length > 0
        xmin = new Date(state.data[state.data.length - 1].day * 1000)
        xmax = new Date(state.data[0].day * 1000)


      # yscale adjust
      ydatamin = 9007199254740992
      ydatamax = 0
      for name in @props.datanames
        ydatamin = Math.min d3.min(state.data, (d) => d[name]), ydatamin
        ydatamax = Math.max d3.max(state.data, (d) => d[name]), ydatamax
      
      ymin = Math.max 0, (ydatamin - @props.domainmargin)
      ymax = ydatamax + @props.domainmargin

      if isNaN(ymin) or isNaN(ymax)
        ymin = 0
        ymax = 0

      xscale: d3.time.scale()
        .range([0, @plotwidth()])
        .domain([xmin, xmax])
      yscale: d3.scale.linear()
        .range([@plotheight(), 0])
        .domain([ymin, ymax])

    axes: (el, scales) ->
      # Render axes
      xaxis = d3.svg.axis()
        .scale(scales.xscale)
        .orient('bottom')
        .tickFormat(d3.time.format('%b %d'))
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
      for name,i in @props.datanames
        # Create a line function
        lfunc = d3.svg.line()
          .x((d) => scales.xscale(new Date(d.day*1000)))
          .y((d) => scales.yscale(d[name]))
          .interpolate('linear')

        # Draw to plot
        d3.select(el).select("path.line#{i}")
          .attr('d', lfunc(state.data))
