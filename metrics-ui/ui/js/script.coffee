requirejs.config
  paths:
    components: 'components'
    jquery: 'https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min'
    react: 'https://fb.me/react-0.12.2'
    d3: 'https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3'

require ['jquery', 'd3', 'react', 'components/linechart-react'], ($, d3, React, linechart) ->
  {div, h4, p} = React.DOM

  Graph = React.createFactory React.createClass
    displayName: 'graph'
    getInitialState: ->
      todoTotals: [] 
    componentDidMount: ->
      $.get '/api/totals/last/10', (result) =>
        data = result
        @setState {todoTotals: data}
    render: ->
      linechart
        data: @state.todoTotals
        margin:
          top: 5
          right: 15
          bottom: 50
          left: 30
        width: 500
        height: 300

  Ui = React.createFactory React.createClass
    render: ->
      div className: "section", [
        div className: "container", [
          div className: "row", [
            (h4 className: "section-heading", "Basic Daily Report"),
            (p className: "section-description",
              "This graph shows the total number of tasks on the todo board over time."),
            (Graph {})
          ]
        ]
      ]
      
  $ ->
    React.render (Ui {}), document.body
