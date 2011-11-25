Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1
Array::find = (e) -> t if (t = @indexOf(e)) > -1

changing = false

kiosks = []
chrome.extension.sendRequest
  action: 'get'
  type: 'kiosks'
  (response) ->
    kiosks = response

$("table.storeresults tr").live
  DOMSubtreeModified: -> 
    if !changing
      changing = true
      kioskid = $(this).find('td:eq(3) a[kioskid]').attr('kioskid')
      if $($(this).find('td:eq(3) a[id="kioskid_' + kioskid + '"]')).length == 0
        wuw = if kiosks.find(kioskid) == undefined then 'Watch' else 'UnWatch'
        nl = $($(this).find('td:eq(3)')).append('<br/><a id="kioskid_' + kioskid + '">' + wuw + '</a>')
        locName = $($(this).find('td:eq(1) span')).text()
        locAddr = $($(this).find('td:eq(1) p')).text()
        nl.click ->
          if $('#kioskid_' + kioskid).text() == 'Watch'
            $('#kioskid_' + kioskid).text('UnWatch')
            chrome.extension.sendRequest
              action: 'watch'
              type: 'kiosk'
              id: kioskid
              name: $.trim(locName)
              addr: $.trim(locAddr)
          else
            $('#kioskid_' + kioskid).text('Watch')
            chrome.extension.sendRequest
              action: 'unwatch'
              type: 'kiosk'
              id: kioskid
          true
      changing = false

$(document).ready ->
  chrome.extension.sendRequest
    action: 'get'
    type: 'items'
    (wis) ->
      watchitems = wis
      $(document).on
        mouseenter: ->
          key = $(this).attr('key')
          wuw = if watchitems.find(key) == undefined then 'Track' else 'UnTrack'
          wa = $(this).prepend('<div class="rbw-clicker" id="watchitem_' + key + '">' + wuw + '</div>')
          wa.click ->
            if $('#watchitem_' + key).text() == 'Track'
              chrome.extension.sendRequest
                action: 'watch'
                type: 'item'
                id: key
                (wis) ->
                  watchitems = wis
                  $('#watchitem_' + key).text('UnTrack')
            else
              chrome.extension.sendRequest
                action: 'unwatch'
                type: 'item'
                id: key
                (wis) ->
                  $('#watchitem_' + key).text('Track')
                  watchitems = wis
            true
        mouseleave: ->
          $(this).children().first().remove()
        "div.box-wrapper"
