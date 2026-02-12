// Main JavaScript for Stock Options Lab
let coveredCallsChart = null;
let verticalSpreadsChart = null;
let coveredCallsTable = null;
let verticalSpreadsTable = null;

function jsMain() {
  // Initialize charts
  coveredCallsChart = echarts.init(document.getElementById('coveredCallsChart'));
  verticalSpreadsChart = echarts.init(document.getElementById('verticalSpreadsChart'));
  
  // Initialize tables
  initTables();
  
  // Load default ticker
  loadStockOptions();
  
  // Handle window resize
  window.addEventListener('resize', function() {
    coveredCallsChart.resize();
    verticalSpreadsChart.resize();
  });
}

function initTables() {
  const ccColumnDefs = [
    { field: 'underlying', headerName: 'Stock', width: 100 },
    { field: 'call', headerName: 'Call Option', width: 200 },
    { field: 'strike', headerName: 'Strike', width: 100, valueFormatter: p => '$' + p.value.toFixed(2) },
    { field: 'DTE', headerName: 'DTE', width: 80 },
    { field: 'premiumToReceive', headerName: 'Premium', width: 120, valueFormatter: p => '$' + p.value.toFixed(2) },
    { field: 'breakEven', headerName: 'Break Even', width: 120, valueFormatter: p => p.value ? '$' + p.value.toFixed(2) : 'N/A' },
    { field: 'breakEvenAsChange', headerName: 'BE %', width: 100, valueFormatter: p => p.value ? (p.value * 100).toFixed(1) + '%' : 'N/A' },
    { field: 'maxYield', headerName: 'Max Yield', width: 120, valueFormatter: p => (p.value * 100).toFixed(1) + '%' },
    { field: 'maxYieldAt', headerName: 'Max Yield At', width: 120, valueFormatter: p => '$' + p.value.toFixed(2) },
    { field: 'yieldIfPriceUnchanged', headerName: 'Yield @ Current', width: 150, valueFormatter: p => (p.value * 100).toFixed(1) + '%' }
  ];
  
  const vsColumnDefs = [
    { field: 'underlying', headerName: 'Stock', width: 100 },
    { field: 'type', headerName: 'Type', width: 100 },
    { field: 'shortLeg', headerName: 'Short Leg', width: 200 },
    { field: 'longLeg', headerName: 'Long Leg', width: 200 },
    { field: 'DTE', headerName: 'DTE', width: 80 },
    { field: 'credit', headerName: 'Credit', width: 100, valueFormatter: p => '$' + p.value.toFixed(2) },
    { field: 'breakEven', headerName: 'Break Even', width: 120, valueFormatter: p => p.value ? '$' + p.value.toFixed(2) : 'N/A' },
    { field: 'maxYield', headerName: 'Max Yield', width: 120, valueFormatter: p => (p.value * 100).toFixed(1) + '%' },
    { field: 'maxRisk', headerName: 'Max Risk', width: 120, valueFormatter: p => '$' + p.value.toFixed(2) },
    { field: 'yieldIfPriceUnchanged', headerName: 'Yield @ Current', width: 150, valueFormatter: p => (p.value * 100).toFixed(1) + '%' }
  ];
  
  const ccGridOptions = {
    columnDefs: ccColumnDefs,
    defaultColDef: {
      sortable: true,
      filter: true,
      resizable: true
    },
    pagination: true,
    paginationPageSize: 25
  };
  
  const vsGridOptions = {
    columnDefs: vsColumnDefs,
    defaultColDef: {
      sortable: true,
      filter: true,
      resizable: true
    },
    pagination: true,
    paginationPageSize: 25
  };
  
  const ccTableElement = document.getElementById('coveredCallsTable');
  const vsTableElement = document.getElementById('verticalSpreadsTable');
  
  if (ccTableElement) {
    coveredCallsTable = agGrid.createGrid(ccTableElement, ccGridOptions);
  }
  if (vsTableElement) {
    verticalSpreadsTable = agGrid.createGrid(vsTableElement, vsGridOptions);
  }
}

async function loadStockOptions() {
  const ticker = document.getElementById('stockTicker').value.trim().toUpperCase();
  if (!ticker) {
    alert('Please enter a stock ticker');
    return;
  }
  
  // Update display
  document.getElementById('currentTicker').textContent = ticker;
  document.getElementById('stockPriceDisplay').textContent = 'Loading ' + ticker + ' options...';
  
  try {
    // Fetch covered calls
    const ccData = await coveredCallsDart(ticker, 0.5);
    const ccJson = JSON.parse(ccData);
    
    // Fetch vertical spreads
    const vsData = await verticalSpreadsDart(ticker, 0.5);
    const vsJson = JSON.parse(vsData);
    
    // Update price display
    if (ccJson.length > 0 && ccJson[0].spotPrice) {
      document.getElementById('stockPriceDisplay').innerHTML = 
        `<strong>${ticker}</strong> Current Price: <span style="color: #4a7cff; font-size: 1.2em;">$${ccJson[0].spotPrice.toFixed(2)}</span>`;
    }
    
    // Update charts and tables
    updateCoveredCallsChart(ccJson);
    updateVerticalSpreadsChart(vsJson);
    
    if (coveredCallsTable) {
      coveredCallsTable.setGridOption('rowData', ccJson);
    }
    if (verticalSpreadsTable) {
      verticalSpreadsTable.setGridOption('rowData', vsJson);
    }
    
  } catch (error) {
    console.error('Error loading options:', error);
    document.getElementById('stockPriceDisplay').textContent = 
      'Error loading options for ' + ticker + '. Please try again.';
  }
}

function updateCoveredCallsChart(data) {
  if (!data || data.length === 0) return;
  
  // Scatter plot: Break-Even % vs Max Yield
  const scatterData = data.map(item => ({
    name: item.call,
    value: [
      (item.breakEvenAsChange || 0) * 100, // X: Break-Even as %
      (item.maxYield - 1) * 100,           // Y: Max Yield as %
      item.strike,                          // Size: strike
      item.DTE                              // Color: DTE
    ],
    ...item
  }));
  
  const option = {
    backgroundColor: 'transparent',
    title: {
      text: 'Covered Calls: Return vs Protection',
      left: 'center',
      textStyle: { color: '#eaeaea' }
    },
    tooltip: {
      trigger: 'item',
      formatter: function(params) {
        const d = params.data;
        return `<strong>${d.call}</strong><br/>
                Strike: $${d.strike.toFixed(2)}<br/>
                DTE: ${d.DTE}<br/>
                Break-Even: ${((d.breakEvenAsChange || 0) * 100).toFixed(1)}%<br/>
                Max Yield: ${((d.maxYield - 1) * 100).toFixed(1)}%<br/>
                Premium: $${d.premiumToReceive.toFixed(2)}`;
      }
    },
    grid: {
      left: '10%',
      right: '10%',
      bottom: '15%',
      top: '15%'
    },
    xAxis: {
      name: 'Downside Protection (%)',
      nameLocation: 'middle',
      nameGap: 30,
      type: 'value',
      axisLabel: { formatter: '{value}%', color: '#aaa' },
      axisLine: { lineStyle: { color: '#555' } },
      splitLine: { lineStyle: { color: '#333' } },
      nameTextStyle: { color: '#eaeaea' }
    },
    yAxis: {
      name: 'Max Return (%)',
      nameLocation: 'middle',
      nameGap: 40,
      type: 'value',
      axisLabel: { formatter: '{value}%', color: '#aaa' },
      axisLine: { lineStyle: { color: '#555' } },
      splitLine: { lineStyle: { color: '#333' } },
      nameTextStyle: { color: '#eaeaea' }
    },
    visualMap: {
      min: 0,
      max: 90,
      dimension: 3,
      orient: 'horizontal',
      right: 10,
      top: 10,
      text: ['Far', 'Near'],
      calculable: true,
      inRange: {
        color: ['#50a3ba', '#eac736', '#d94e5d']
      },
      textStyle: { color: '#eaeaea' }
    },
    series: [{
      name: 'Covered Calls',
      type: 'scatter',
      symbolSize: function(data) {
        return Math.sqrt(data[2]) * 1.5;
      },
      data: scatterData,
      itemStyle: {
        shadowBlur: 10,
        shadowColor: 'rgba(74, 124, 255, 0.5)'
      }
    }]
  };
  
  coveredCallsChart.setOption(option, true);
}

function updateVerticalSpreadsChart(data) {
  if (!data || data.length === 0) return;
  
  // Separate over and under spreads
  const overs = data.filter(d => d.type === 'over');
  const unders = data.filter(d => d.type === 'under');
  
  const option = {
    backgroundColor: 'transparent',
    title: {
      text: 'Vertical Spreads: Risk vs Reward',
      left: 'center',
      textStyle: { color: '#eaeaea' }
    },
    tooltip: {
      trigger: 'item',
      formatter: function(params) {
        const d = params.data;
        return `<strong>${d.type.toUpperCase()}</strong><br/>
                ${d.shortLeg}<br/>
                ${d.longLeg}<br/>
                DTE: ${d.DTE}<br/>
                Credit: $${d.credit.toFixed(2)}<br/>
                Max Yield: ${((d.maxYield - 1) * 100).toFixed(1)}%<br/>
                Max Risk: $${d.maxRisk.toFixed(2)}`;
      }
    },
    legend: {
      data: ['Over Spreads', 'Under Spreads'],
      bottom: 10,
      textStyle: { color: '#eaeaea' }
    },
    grid: {
      left: '10%',
      right: '10%',
      bottom: '15%',
      top: '15%'
    },
    xAxis: {
      name: 'Max Risk ($)',
      nameLocation: 'middle',
      nameGap: 30,
      type: 'value',
      axisLabel: { formatter: '${value}', color: '#aaa' },
      axisLine: { lineStyle: { color: '#555' } },
      splitLine: { lineStyle: { color: '#333' } },
      nameTextStyle: { color: '#eaeaea' }
    },
    yAxis: {
      name: 'Max Return ($)',
      nameLocation: 'middle',
      nameGap: 40,
      type: 'value',
      axisLabel: { formatter: '${value}', color: '#aaa' },
      axisLine: { lineStyle: { color: '#555' } },
      splitLine: { lineStyle: { color: '#333' } },
      nameTextStyle: { color: '#eaeaea' }
    },
    series: [
      {
        name: 'Over Spreads',
        type: 'scatter',
        symbolSize: 15,
        data: overs.map(d => ({
          value: [d.maxRisk, (d.maxYield - 1) * d.maxRisk],
          ...d
        })),
        itemStyle: { color: '#eac736' }
      },
      {
        name: 'Under Spreads',
        type: 'scatter',
        symbolSize: 15,
        data: unders.map(d => ({
          value: [d.maxRisk, (d.maxYield - 1) * d.maxRisk],
          ...d
        })),
        itemStyle: { color: '#50a3ba' }
      }
    ]
  };
  
  verticalSpreadsChart.setOption(option, true);
}

// Allow Enter key to trigger search
document.addEventListener('DOMContentLoaded', function() {
  const tickerInput = document.getElementById('stockTicker');
  if (tickerInput) {
    tickerInput.addEventListener('keypress', function(e) {
      if (e.key === 'Enter') {
        loadStockOptions();
      }
    });
  }
});
