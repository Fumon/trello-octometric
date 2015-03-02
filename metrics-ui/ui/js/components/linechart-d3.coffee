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

      # Make plotline placeholder and axis legend
      for d, i in @props.derived
        data.append('path')
          .attr('class', "line#{d.name}")
        label = d.name.replace(/_/g, " ")
        axislabel = data.append("g")
          .attr("class", "label")
          .attr("transform",
            "translate(100, #{16*(i+1)})")
        
        axislabel.append("text")
          .style("text-anchor", "end")
          .attr("dx", "-5")
          .text(label)
        axislabel.append("rect")
          .attr("class", "labelcolor#{d.name}")
          .attr("transform",
            "translate(0, -8)")
          .attr("width", 12)
          .attr("height", 12)
          .attr("rx", 2.5)
          .attr("ry", 2.5)
        if d.trendline == true
          data.append('line')
            .attr
              class: "trendline trend#{d.name}"
              x1: 0
              x2: @plotwidth()


      if @props.zeroline?
        data.append('line')
          .attr
            class: "zero zero#{@props.zeroline.axis}"
            x1: 0
            x2: @plotwidth()

      # Append axes placeholders
      data.append('g')
        .attr('class', 'x axis')
        .attr('transform',
          "translate(0, #{@plotheight()})")

      # Detect associate data with axes
      @dataaxes = [[], []]
      for d, i in @props.derived
        if d.axis == 0
          if @dataaxes[0].length == 0
            data.append('g')
              .attr('class', 'y0 axis')
          @dataaxes[0].push(d)
        if d.axis == 1
          if @dataaxes[1].length == 0
            data.append('g')
              .attr('class', 'y1 axis')
              .attr('transform',
                "translate(#{@plotwidth()}, 0)")
          @dataaxes[0].push(d)

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

      scales_.xscale = d3.time.scale()
        .range([0, @plotwidth()])
        .domain([xmin, xmax])

      for a, i in @dataaxes
        if a.length > 0
          max = -9007199254740992
          min = 9007199254740992
          for b in a
            max = Math.max d3.max(state.data, (d) => b.func(d)), max
            min = Math.min d3.min(state.data, (d) => b.func(d)), min
          min = min - @props.domainmargin
          max = max + @props.domainmargin
          if isNaN(min) or isNaN(max)
            min = 0
            max = 0
          scales_["yscale#{i}"] = d3.scale.linear()
            .range([@plotheight(), 0])
            .domain([min, max])

      scales_

    axes: (el, scales) ->
      # Render axes
      xaxis = d3.svg.axis()
        .scale(scales.xscale)
        .orient('bottom')
        .tickFormat(d3.time.format('%b %d'))

      xaxisdrawn = d3.select(el).select('g.x.axis')
        .call(xaxis)

      xaxisdrawn.selectAll('text')
        .style('text-anchor', 'end')
        .attr('transform', 'rotate(-65)')

      for n, i in @dataaxes
        if n.length > 0
          yaxis = d3.svg.axis()
            .scale(scales["yscale#{i}"])
          if i == 0
            yaxis.orient('left')
          else if i == 1
            yaxis.orient('right')
          d3.select(el).select("g.y#{i}.axis")
            .call(yaxis)

    drawplot: (el,scales,state) ->
      for a,i in @dataaxes
        yscale = scales["yscale#{i}"]
        if @props.zeroline? && @props.zeroline.axis == i
          d3.select(el).select("line.zero#{i}")
            .attr
              x2: @plotwidth()
              y1: yscale(0)
              y2: yscale(0)
        for n in a
          # Create a line function
          lfunc = d3.svg.line()
            .x((d) => scales.xscale(new Date(d.day*1000)))
            .y((d) => yscale(n.func(d)))
          
          lfunc.interpolate('monotone')

          # Draw to plot
          d3.select(el).select("path.line#{n.name}")
            .attr('d', lfunc(state.data))
          # Draw trendlines
          if n.trendline == true && state.data.length > 0
            yval = yscale(n.func(state.data[0]))
            d3.select(el).select("line.trend#{n.name}")
              .attr
                x2: @plotwidth()
                y1: yval
                y2: yval
                

