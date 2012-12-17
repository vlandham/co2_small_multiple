# ---
# Using the 'reusable charts' style closure for 
# encapsulating the visualization code
# ---
SmallMults = () ->
  # ---
  # Variables availible to all of SmallMults
  # ---
  
  # size of the svg's that hold the small multiples 
  width = 200
  height = 160
  # size of the drawing area inside the svg's to make
  # the bar charts
  graphWidth = 180
  graphHeight = 140
  # padding used underneath the bars to make space
  # for the names of the countries
  yPadding = 12
  # placeholder for the data
  data = []

  # using an ordinal scale for X as our
  # data is categorical (the names of countries)
  xScale = d3.scale.ordinal()
    .rangeRoundBands([0, graphWidth], 0.1)

  # names will also be used to color the bars
  colorScale = d3.scale.ordinal()
    .range(["#ff7f0e", "#1f77b4", "#2ca02c", "#d62728", "#8c564b", "#9467bd"])

  # yPadding is removed to make room for country names
  yScale = d3.scale.linear()
    .range([0, graphHeight - yPadding])

  # This is the amount by which we will enlarge the small chart 
  # when displaying it in detail display
  scaleFactor = 4

  # ---
  # Main entry point for our visualization.
  # SVG elements for each small chart are created
  # as well as graph inside each SVG.
  # ---
  chart = (selection) ->
    selection.each (rawData) ->
      # store our data and set the scale domains
      data = rawData
      setScales()
      createLegend()

      # bind data to svg elements so there will be a svg for
      # each year
      pre = d3.select(this).select("#previews")
        .selectAll(".preview").data(data)

      # create the svg elements
      pre.enter()
        .append("div")
        .attr("class", "preview")
        .attr("width", width)
        .attr("height", height)

      svgs = pre.append("svg")
        .attr("width", width)
        .attr("height", height)

      # create a group for displaying the barchart in
      previews = svgs.append("g")
       
      # draw the graphs for each data element.
      # This will call 'drawChart' for each element
      # of the data and will pass in the data as well
      # as the associated group element where the 
      # chart is to be drawn
      previews.each(drawChart)

      # create a rect overlay that will intercept
      # mouse clicks and show detail view of clicked
      # graph
      previews.append("rect")
        .attr("width", graphWidth)
        .attr("height", graphHeight)
        .attr("class", "mouse_preview")
        .on("click", showDetail)

  # ---
  # Code for drawing a single barchart
  # ---
  drawChart = (d,i) ->
    # the 'this' element is the group
    # element which the barchart will
    # live in
    base = d3.select(this)
    base.append("rect")
      .attr("width", graphWidth)
      .attr("height", graphHeight)
      .attr("class", "background")

    # create the bars
    graph = base.append("g")
    graph.selectAll(".bar")
      .data((d) -> d.values)
      .enter().append("rect")
      .attr("x", (d) -> xScale(d.name))
      .attr("y", (d) -> (graphHeight - yScale(d.value) - yPadding))
      .attr("width", xScale.rangeBand())
      .attr("height", (d) ->  yScale(d.value))
      .attr("fill", (d) -> colorScale(d.name))
      .on("mouseover", showAnnotation)
      .on("mouseout", hideAnnotation)

    # add the year title
    graph.append("text")
      .text((d) -> d.year)
      .attr("class", "title")
      .attr("text-anchor", "middle")
      .attr("x", graphWidth / 2)
      .attr("dy", "1.3em")

  # ---
  # This creates the additional text displayed for
  # the detail view.
  # ---
  drawDetails = (d,i) ->
    # like in 'drawChart', 'this'
    # is the group element to draw
    # the details in
    graph = d3.select(this)

    # add names under bars
    graph.selectAll(".name")
      .data(d.values).enter()
      .append("text")
      .attr("class", "name")
      .text((d) -> d.name)
      .attr("text-anchor", "middle")
      .attr("y", graphHeight - yPadding)
      .attr("dy", "1.3em")
      .attr("x", (d) -> xScale(d.name) + xScale.rangeBand() / 2)
      .attr("font-size", 8)

    # add values above bars
    graph.selectAll(".amount")
      .data(d.values).enter()
      .append("text")
      .attr("class", "amount")
      .text((d) -> if d.value == 0 then "No Data" else shortenNumber(d.value))
      .attr("text-anchor", "middle")
      .attr("y", (d) -> (graphHeight - yScale(d.value) - yPadding))
      .attr("dy", (d) -> if yScale(d.value) < 10 then "-0.3em" else "1.1em")
      .attr("x", (d) -> xScale(d.name) + xScale.rangeBand() / 2)
      .attr("font-size", 5)

  # ---
  # Shows the detail view for a given element
  # This works by appending a copy of the graph
  # to the 'detail' svg while switching the
  # detail section to visible
  # ---
  showDetail = (d,i) ->
    # switch the css on which divs are hidden
    toggleHidden(true)
    
    detailView = d3.select("#detail_view")

    # clear any existing detail view
    detailView.selectAll('.main').remove()

    # bind the single element to be detailed to the 
    # detail view's group
    detailG = detailView.selectAll('g').data([d]).enter()

    # create a new group to display the graph in
    main = detailG.append("g")
      .attr("class", "main")

    # draw graph just like in the initial creation
    # of the small multiples
    main.each(drawChart)

    # add details specific to the detail view
    main.each(drawDetails)

    # setup click handler to hide detail view once
    # graph or detail panel is clicked
    main.on("click", () -> hideDetail(d,i))
    d3.select("#detail").on("click", () -> hideDetail(d,i))
   
    # Here is the code responsible for the lovely zoom
    # affect of the detail view
    
    # getPosition is a helper function to
    # return the relative location of the graph
    # to be viewed in the detail view
    pos = getPosition(i)
    # scrollTop returns the number of pixels
    # hidden on the top of the window because of
    # the window being scrolled down
    # http://api.jquery.com/scrollTop/
    scrollTop = $(window).scrollTop()

    # first we move our (small) detail graph to be positioned over
    # its preview version
    main.attr('transform', "translate(#{pos.left},#{pos.top - scrollTop})")
    # then we use a transition to center the detailed graph and scale it
    # up to be bigger
    main.transition()
      .delay(500)
      .duration(500)
      .attr('transform', "translate(#{40},#{0}) scale(#{scaleFactor})")

  # ---
  # This function shrinks the detail view back from whence it came
  # ---
  hideDetail = (d,i) ->
    # see showDetail for... details
    pos = getPosition(i)
    scrollTop = $(window).scrollTop()

    # Use transition to move the detail panel back 
    # down to its preview's location
    # The view also shrinks back to its preview size
    # because d3's transition can tween between the 
    # scale it had, and the lack of scale here.
    d3.selectAll('#detail_view .main').transition()
      .duration(500)
      .attr('transform', "translate(#{pos.left},#{pos.top - scrollTop})")
      .each 'end', () ->
        toggleHidden(false)

  # ---
  # Toggles hidden css between the previews and detail view divs
  # if show is true, the detail view is shown
  # ---
  toggleHidden = (show) ->
    d3.select("#previews").classed("hidden", show).classed("visible", !show)
    d3.select("#detail").classed("hidden", !show).classed("visible", show)

  # ---
  # Add subtitle that indicates what percantage of
  # world wide emissions the country is at that year
  # Serves as example of simple additional interactions
  # in detail view
  # ---
  showAnnotation = (d) ->
    graph = d3.select("#detail_view .main")
    graph.selectAll(".subtitle").remove()

    graph.selectAll(".subtitle")
      .data([d]).enter()
      .append("text")
      .text("#{formatNumber(d.percent_world * 100)}% of Worldwide Emissions")
      .attr("class", "subtitle")
      .attr("fill", (d) -> colorScale(d.name))
      .attr("text-anchor", "middle")
      .attr("dy", "3.8em")
      .attr("x", (d) -> graphWidth / 2)
      .attr("font-size", 8)

  # ---
  # remove subtitle
  # ---
  hideAnnotation = (d) ->
    graph = d3.select("#detail_view .main")
    graph.selectAll(".subtitle").remove()

  # ---
  # Updates domains for scales used in bar charts
  # expects 'data' to be accessible and set to our
  # data.
  # ---
  setScales = () ->
    yMax = d3.max(data, (d) -> d3.max(d.values, (e) -> e.value))
    # this scale is expanded past its max to provide some white space
    # on the top of the bars
    yScale.domain([0,yMax + 500000])

    names = data[0].values.map (d) -> d.name
    xScale.domain(names)
    colorScale.domain(names)

  # ---
  # Helper function to return the position
  # of a preview graph at index i
  # ---
  getPosition = (i) ->
    el = $('.preview')[i]
    # http://api.jquery.com/position/
    pos = $(el).position()
    pos

  createLegend = () ->
    legend = d3.select("#legend")
      .append("svg")
      .attr("width", 100)
      .attr("height", 300)

    keys = legend.selectAll("g")
      .data(data[0].values)
      .enter().append("g")
      .attr("transform", (d,i) -> "translate(#{0},#{40 * (i + 1)})")

    keys.append("rect")
      .attr("width", 30)
      .attr("height", 30)
      .attr("fill", (d) -> colorScale(d.name))

    keys.append("text")
      .text((d) -> d.name)
      .attr("text-anchor", "left")
      .attr("dx", "2.2em")
      .attr("dy", "1.2em")

  return chart

# ---
# General helper functions
# to assist with formatting numbers
# ---

# ---
# converts number to string and
# adds commas
# ---
addCommas = (number) ->
  number += ''
  values = number.split('.')
  num = values[0]
  dec = if values.length > 1 then '.' + values[1] else ''
  rgx = /(\d+)(\d{3})/
  while rgx.test(num)
    num = num.replace(rgx, '$1' + ',' + '$2')
  num + dec

# ---
# round to a specific decimal
# ---
roundNumber = (number, decimals) ->
  Math.round(number * Math.pow(10, decimals)) / Math.pow(10, decimals)

# ---
# add commas and round number
# ---
formatNumber = (number) ->
  addCommas(roundNumber(number,0))

# ---
# Millions -> M
# Thousands -> K
# ---
shortenNumber = (number) ->
  if number > 1000000
    addCommas(roundNumber(number / 1000000,1)) + "M"
  else if number > 1000
    addCommas(roundNumber(number / 1000,0)) + "K"
  else
    addCommas(roundNumber(number,0))

# ---
# Given the div, data, and plot
# this function calls the plot in the
# fashion of the reusable chart example
# http://bost.ocks.org/mike/chart/
# ---
plotData = (selector, data, plot) ->
  d3.select(selector)
    .datum(data)
    .call(plot)

# Document is ready. Lets do this.
$ ->
  plot = SmallMults()
  display = (data) ->
    plotData("#vis", data, plot)

  d3.json("data/co2_kt_data.json", display)

