
## Features

- Validation of listen entries
    - This ensures that listens comply with [ListenBrainz standard](https://listenbrainz.readthedocs.io/en/latest/dev/api/#post--1-submit-listens)
    - Tracks with a listen time of <5s are automatically skipped (to reduce impact on Spotify API calls to check playtime vs song duration)
    - Every duration check of song duration from Spotify API is cached in `durations.yaml`, this allows for quicker rerunning and prevents calling the API for multiple listens of a song (all the optimisation!)

## To Do

- Automatically reject playtimes <5s
    - For _really_ short songs being skipped this could be an issue (although if you're skipping a 4s grindcore song do you even _deserve_ the listen?)
- Flag to enable debug comments, run silently otherwise
- Use MusicBrainz API instead of Spotify (slightly kinder rate limit and Open Source hooray)
