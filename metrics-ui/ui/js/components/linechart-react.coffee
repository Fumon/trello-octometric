define ['d3', 'react', 'components/linechart-d3'], (d3, react, chart) ->
  react.createFactory react.createClass
    displayName: 'lineplot'
    propTypes:
      data: react.PropTypes.array
      margin: react.PropTypes.object
      domainmargin: react.PropTypes.number
    
    componentDidMount: () ->
      @chart = new chart.linechart
        
      @chart.create @getDOMNode(),
        {
          datanames: @props.datanames
          domainmargin: @props.domainmargin
          margin: @props.margin
          width: @props.width
          height: @props.height
        },
        data: @props.data
    componentDidUpdate: () ->
      @chart.update @getDOMNode(),
        data: @props.data
    
    render: () ->
      react.DOM.div className: 'linechart'

        
