dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end
  
  if downloaded[url] ~= true and addedtolist[url] ~= true then
    if (string.match(url, "[^0-9]"..item_value.."[0-9]") and not string.match(url, "[^0-9]"..item_value.."[0-9][0-9]")) or html == 0 then
      addedtolist[url] = true
      return true
    else
      return false
    end
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla, origurl)
    local url = string.match(urla, "^([^#]+)")
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and ((string.match(url, "[^0-9]"..item_value.."[0-9]") and not string.match(url, "[^0-9]"..item_value.."[0-9][0-9]")) or string.match(url, "get_topic_id") or string.match(url, "viewtopic%.php%?p=") or string.match(url, "%.jpg$") or string.match(url, "%.png$") or string.match(url, "%.gif$") or string.match(url, "%.jpeg$") or (string.match(url, "^https?://[^/]*fastpic.ru") and not string.match(origurl, "^https?://[^/]*fastpic.ru")) or (string.match(url, "^https?://[^/]*radikal.ru") and not string.match(origurl, "^https?://[^/]*radikal.ru")) or (string.match(url, "^https?://[^/]*imageban.ru") and not string.match(origurl, "^https?://[^/]*imageban.ru")) or (string.match(url, "^https?://[^/]*imagebam.com") and not string.match(origurl, "^https?://[^/]*imagebam.com")) or (string.match(url, "^https?://[^/]*lostpic.net") and not string.match(origurl, "^https?://[^/]*lostpic.net"))) then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?://") then
      check(newurl, url)
    elseif string.match(newurl, "^//") then
      check("http:"..newurl, url)
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl, url)
    elseif string.match(newurl, "%.jpg$") or string.match(newurl, "%.gif$") then
      check(string.match(url, "^(https?://[^/]+/)")..newurl, url)
    end
  end
  
  if (string.match(url, "[^0-9]"..item_value.."[0-9]") and not string.match(url, "[^0-9]"..item_value.."[0-9][0-9]")) or string.match(url, "^https?://[^/]*fastpic.ru") or string.match(url, "^https?://[^/]*f%-picture.net") or string.match(url, "^https?://[^/]*radikal.ru") or string.match(url, "^https?://[^/]*imageban.ru") or string.match(url, "^https?://[^/]*imagebam.com") or string.match(url, "^https?://[^/]*lostpic.net") then
    html = read_file(file)
    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">([^<]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "post_([0-9]+)") do
      check("http://rutracker.org/forum/viewtopic.php?p="..newurl, url)
    end
    if string.match(url, "https?://api%.rutracker%.org/v1/get_tor_hash%?by=topic_id&val=") and string.match(html, '"'..item_value..'[0-9]":"([^"]+)"') then
      check("http://api.rutracker.org/v1/get_topic_id?by=hash&val="..string.match(html, '"'..item_value..'[0-9]":"([^"]+)"'), url)
    end
    if string.match(url, "&guest=1") and not string.match(url, "&dummy=") then
      check(url.."&dummy=")
    end
  end
  
  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403 and status_code ~= 400 and status_code ~= 414) then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if string.match(url, "https?://[^/]*rutracker%.org[^/]*") then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 10")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if string.match(url, "https?://[^/]*rutracker%.org[^/]*") then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0
  if string.match(url, "https?://[^/]*rutracker%.org[^/]*") then
    sleep_time = 0.2
  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
