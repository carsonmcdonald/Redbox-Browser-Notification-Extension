Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1
Array::find = (e) -> t if (t = @indexOf(e)) > -1
String::startsWith = (str) -> this.indexOf(str) == 0

class Background
  RB_URL = 'http://www.redbox.com/'

  constructor: ->
    localStorage["kiosks"] = JSON.stringify([]) if not localStorage["kiosks"]
    localStorage["items"] = JSON.stringify([]) if not localStorage["tems"]

    @notify_items = new Array()

    $.ajax
      url: 'templates/notification.html'
      type: 'GET'
      processData: false
      success: (data, textStatus, jqXHR) =>
        @notification_template = data
      error: @handleAjaxError

    chrome.extension.onRequest.addListener (request, sender, sendResponse) =>
      switch request.action
        when "get"
          sendResponse(JSON.parse(localStorage[request.type]))
        when "watch"
          storage = JSON.parse(localStorage[request.type+'s'])
          storage.push(request.id)
          localStorage[request.type+'s'] = JSON.stringify(storage)
          sendResponse(JSON.parse(localStorage[request.type+'s']))
        when "unwatch"
          storage = JSON.parse(localStorage[request.type+'s'])
          storage.remove(request.id)
          localStorage[request.type+'s'] = JSON.stringify(storage)
          sendResponse(JSON.parse(localStorage[request.type+'s']))
        when "notify"
          $.ajax
            url: RB_URL + 'api/Store/SelectStore/' + @notify_items[request.id].kiosks[0]
            type: 'POST'
            data: '{"returnUserStores":false}'
            dataType: 'json'
            success: (dataA, textStatusA, jqXHRA) =>
              $.ajax
                url: RB_URL + 'api/Product/GetDetail/'
                type: 'POST'
                data: '{"id":"' + @notify_items[request.id].id + '","descCharLimit":300}'
                dataType: 'json'
                success: (dataB, textStatusB, jqXHRB) =>
                  uri = dataB['d']['data']['name'].replace(/\(|\)|\'|:|\"/g, '').replace(/\s/g, '-')
                  html = Mustache.to_html(@notification_template, {id: @notify_items[request.id].id, vname: dataB['d']['data']['name'], vuri: uri, kid: dataA['d']['data']['selectedStore'].id, kinfo: dataA['d']['data']['selectedStore']['profile']})
                  sendResponse({display: html})
                error: @handleAjaxError
            error: @handleAjaxError

  start: ->
    this.fetchAPIKey()

    window.rbextCheckStatus = => @checkStatus()
    setInterval(window.rbextCheckStatus, 60000)

  checkStatus: ->
    current_time = new Date().getTime()
    for id, notify of @notify_items
      if id.startsWith('item_') and notify.ts != null and notify.ts + (60000 * 10) < current_time
        delete @notify_items[id]

    $.ajax
      url: RB_URL + "api/Store/GetStores/"
      type: 'POST'
      data: '{"filters":{"ids":[' + JSON.parse(localStorage['kiosks']).join(',') + ']},"resultOptions":{"inventory":true}}'
      dataType:'json'
      success: @processStatusData
      error: @handleAjaxError

  processStatusData: (data, textStatus, jqXHR) =>
    for kiosk_data in data['d']['data']
      current_kiosk_id = kiosk_data['id']
      for product in kiosk_data['inventory']['products']
        available_item_index = JSON.parse(localStorage['items']).find(''+product.id)
        if available_item_index != undefined
          current_notification = @notify_items['item_'+product.id]
          if product.stock
            if current_notification == undefined
              @notify_items['item_'+product.id] = {id: product.id, kiosks: [current_kiosk_id], notification: null, ts: null}
            else if current_notification.kiosks.find(current_kiosk_id) == undefined
              current_notification.kiosks.push(current_kiosk_id)
              current_notification.notification.cancel() if current_notification.notification?
              current_notification.notification = null
          else if current_notification != undefined and current_notification.kiosks.find(current_kiosk_id) != undefined
            current_notification.kiosks.remove(current_kiosk_id)
            current_notification.notification.cancel() if current_notification.notification?
            current_notification.notification = null
            if current_notification.kiosks.length == 0
              delete @notify_items['item_'+product.id]

    for id, notify of @notify_items
      if id.startsWith('item_') and notify.notification == null
        vid = id
        notify.notification = webkitNotifications.createHTMLNotification('notification.html?id='+id)
        notify.notification.onclose = =>
          @notify_items[vid].ts = new Date().getTime()
        notify.notification.show()

  fetchAPIKey: ->
    $.ajax 
      url: RB_URL
      type: 'GET'
      success: (data, textStatus, jqXHR) ->
        apiKeyRE = new RegExp(".*rb.api.key.*'(.*?)'.*")
        match = apiKeyRE.exec(data)
        if match != null
          $.ajaxSetup
            beforeSend: (xhr) -> xhr.setRequestHeader('__K', match[1])
      error: @handleAjaxError

  handleAjaxError: (jqXHR, textStatus, errorThrown) =>
    console.log('error: ' + errorThrown)

background = new Background
background.start()
