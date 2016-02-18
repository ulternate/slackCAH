# slackCAH
Play Cards Against Humanity in a Slack channel using slack-ruby-bot

# About
Play Cards Against Humanity in slack to a public or private channel.
* Game can be started from private message with bot or from game board channel
* Follows simple Cards Against Humanity rules.
  * One card czar to choose winner of round
  * All other players submit card(s) for random question
  * Players only see their hand (on their Direct Message channel with the bot)
  * Card Czar doesn't see who's played what, just the final selection of played hands
  * Hands are played into group channel so everyone can laugh/cringe/yell at their teammates answers
  * Points are attributed to determine who wins overall

# Configuration
Follow the guide from the slack-ruby-bot main page for [development](https://github.com/dblock/slack-ruby-bot/blob/master/TUTORIAL.md) or [deployment to Heroku](https://github.com/dblock/slack-ruby-bot/blob/master/DEPLOYMENT.md).


## Env
The .env file created in the above [tutorial](https://github.com/dblock/slack-ruby-bot/blob/master/TUTORIAL.md) requires the following additions:
```
GAME_BOARD_NAME = name_of_game_board
BOT_NAME = name_of_bot

#Set the following to false if you don't want gif's from Slack-ruby-bot
SLACK_RUBY_BOT_SEND_GIFS = false
```

# Thanks/Aknowledgements
Thanks to [slack-ruby-bot](https://github.com/dblock/slack-ruby-bot) and it's developers/contributors for the heavy lifting regarding the bot's connection to Slack and first configuration.

# Updates
This is currently a work in progress so commands might change/break willy nilly. I'm sporadically working on it and hope to have something up here soon.
