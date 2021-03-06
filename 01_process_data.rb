require 'json'
require 'yaml'
require 'rspotify'

# Import cache of song durations from previous runs
duration_cache_file = 'durations.yaml'
if File.exist?(duration_cache_file)
  durations = YAML.load_file(duration_cache_file)
else
  durations = {}
end

# Spotify Auth
auth_file = 'auth.yaml'
if File.exist?(auth_file)
  auth = YAML.load_file(auth_file)
else
  puts "No #{auth_file} file! Create this with client_id and client_secret to continiue!"
  exit
end
RSpotify.authenticate(auth['client_id'], auth['client_secret'])

listens = []
Dir.glob('data/endsong_*.json') do |filename|
  file = File.read(filename)
  listens += JSON.parse(file)
end

valid_listens = []
listens.each_with_index do |track, index|
  puts "Processed: #{index} (valid: #{valid_listens.count})"
  # If track didn't normally end then we need to work out if it played at least half (or 4 mins, whichever is lower)
  if track['reason_end'] != 'trackdone'

    # If playtime is less than 4 mins (280s, 280000ms) then we'll need to compare playtime to song duration
    ## Making this value a float forces decimal output from division, otherwise it's an integer
    playtime = track['ms_played'].to_f 

    # Consider the track a no listen if playtime <5s (5000ms)
    if playtime < 5000
      puts "Playtime less than 5s, skipping"
      next
    end

    if playtime < 280000

      # Gather song metadata from Spotify and compare it to playtime
      begin
        uri = track['spotify_track_uri'].split(':').last
      rescue NoMethodError
        puts "Track has no name - either a nil entry, local file or podcast, skipping..."
        next
      end

      # Retrieve metadata from local cache if present
      if durations.has_key? uri 
        puts "Retrieving duration from cache"
        duration = durations[uri]
      else
        # Safely try to grab duration from Spotify API
        # If it fails, sleep for 60s to allow API limits to reset before trying again
        begin
          puts "Querying Spotify for: #{track['master_metadata_track_name']} (#{track['spotify_track_uri']})"
          song_metadata = RSpotify::Track.find(uri)
        rescue RestClient::NotFound
          puts "Rate limit hit, waiting for 60s before retrying"
          sleep 60
          retry
        end
        duration = song_metadata.duration_ms
        durations[uri] = duration

        # Write to durations cache in case of error
        File.open(duration_cache_file, "w") { |f| f.write(durations.to_yaml) }
        
        # Sleeping here to prevent too many calls and getting rate limited by Spotify
        # This usually manifests as a 404 RestClient::NotFound error
        ## https://developer.spotify.com/documentation/web-api/guides/rate-limits/
        sleep 2
      end
      if playtime / duration >= 0.5 
        # More than half the song has been played, this is a valid listen
        valid_listens += [track]
      end
    else
      # 4 or more minutes of song listened to, this is a valid listen
      valid_listens += [track]
    end
  else
    valid_listens += [track]
  end
end

File.open('valid_listens.yaml', "w") { |f| f.write(valid_listens.to_yaml) }
puts "Total Listens Parsed: #{listens.count}"
puts "Total Valid Listens: #{valid_listens.count}"
