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
        .attr('class', 'd3-data')
        .attr('transform',
          "translate(#{props.margin.left}, #{props.margin.top})")

      datalist = @props.datanames.slice()
      if @props.derived?
        datalist.push @props.derived.name

      # Make plotline placeholder and axis legend
      for name, i in datalist
        data.append('path')
          .attr('class', "line#{name}")
        label = name.replace(/_/g, " ")
        axislabel = data.append("g")
          .attr("class", "label")
          .attr("transform",
            "translate(100, #{16*(i+1)})")
        
        axislabel.append("text")
          .style("text-anchor", "end")
          .attr("dx", "-5")
          .text(label)
        axislabel.append("rect")
          .attr("class", "labelcolor#{name}")
          .attr("transform",
            "translate(0, -8)")
          .attr("width", 12)
          .attr("height", 12)
          .attr("rx", 2.5)
          .attr("ry", 2.5)

      # Append axes placeholders
      data.append('g')
        .attr('class', 'x axis')
        .attr('transform',
          "translate(0, #{@plotheight()})")
      data.append('g')
        .attr('class', 'y axis')

      if @props.derived?
        data.append('g')
          .attr('class', 'y2 axis')
          .attr('transform',
            "translate(#{@plotwidth()}, 0)")


      
      @update el, state
    update: (el, state) ->
      # Recompute scales
      scales = @scales(state)
      # Render axes
      @axes(el, scales)
      @drawplot(el, scales, state)

    scales: (state) ->
      scales_ = {}
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

      scales_.xscale = d3.time.scale()
        .range([0, @plotwidth()])
        .domain([xmin, xmax])
      scales_.yscale = d3.scale.linear()
        .range([@plotheight(), 0])
        .domain([ymin, ymax])

      # Yaxis for derived
      if @props.derived?
        yabsmax = d3.max(state.data, (d) => Math.abs(@props.derived.func(d)))
        scales_.derivedscale = d3.scale.linear()
          .range([@plotheight(), 0])
          .domain([yabsmax*-1, yabsmax])

      scales_

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
      yaxis = d3.select(el).select('g.y.axis')
        .call(yaxis)

      if @props.derived?
        derivedaxis = d3.svg.axis()
          .scale(scales.derivedscale)
          .orient('right')
        d3.select(el).select('g.y2.axis')
          .call(derivedaxis)

    drawplot: (el,scales,state) ->
      dnames = @props.datanames.slice()
      if @props.derived?
        dnames.push @props.derived.name

      for name,i in dnames
        # Create a line function
        lfunc = d3.svg.line()
          .x((d) => scales.xscale(new Date(d.day*1000)))
        if @props.derived? && name == @props.derived.name
          lfunc.y((d) => scales.derivedscale(@props.derived.func(d)))
        else
          lfunc.y((d) => scales.yscale(d[name]))
        
        lfunc.interpolate('monotone')

        # Draw to plot
        d3.select(el).select("path.line#{name}")
          .attr('d', lfunc(state.data))
