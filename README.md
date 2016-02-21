# slackCAH
Play Cards Against Humanity in a Slack channel using [slack-ruby-bot](https://github.com/dblock/slack-ruby-bot)

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

# Playing a game (Bot Commands)
All commands for playing Cards Against Humanity are located in [slac_cah/commands/cah.rb](https://github.com/ulternate/slackCAH/blob/master/slack_cah/commands/cah.rb). New commands should be added here.

The current list of available commands are as follows:
* help - List the commands that the bot takes
* start - Start a game of Cards against humanity. Requires user objects to initiate game with selected players. The following format is needed:
  ```bot_name start @user1 @user2...
  ```
* pick - Select the current card(s) you'd like to play. The following format is needed:
  ```bot_name pick 0 9
  ```
* showCards - Show your current hand. This will appear on your Direct Message (DM) page with the bot.
* showQuestion - Show the current question. Will appear where asked.
* showPlayed - Show the final hands played by all players, useful for the card czar if they've forgotten.
* scores - Show the current scores for all players.
* winner - Select the winning hand if you're the card czar. The following format is needed:
  ```bot_name winner 0
  ```
* reset - Reset the cards deck and clear all players hands. Call start to restart a new game.
* status - See who you're waiting on to play their hand.
* quit - Quit the current game.

# Configuration
The Slack-ruby-bot page has some great guides for setting up a simple bot for [development](https://github.com/dblock/slack-ruby-bot/blob/master/TUTORIAL.md) and [deployment to Heroku](https://github.com/dblock/slack-ruby-bot/blob/master/DEPLOYMENT.md).

The following settings are also required to get this bot running.

#### Development

To get slackCAH running for testing add the following to your .env file created in the development [tutorial](https://github.com/dblock/slack-ruby-bot/blob/master/TUTORIAL.md) above
```
GAME_BOARD_NAME = name_of_game_board
BOT_NAME = name_of_bot

#Set the following to false if you don't want gif's from Slack-ruby-bot
SLACK_RUBY_BOT_SEND_GIFS = false
```

#### Deployment (Heroku)

I found I had to make the following additions from the base [slack-ruby-bot](https://github.com/dblock/slack-ruby-bot) [deployment guide](https://github.com/dblock/slack-ruby-bot/blob/master/DEPLOYMENT.md):

##### Procfile
I had changed $PORT to a dedicated port for testing. Heroku will assign a port to the $PORT tag when your bot runs with puma. So change it back to $PORT before deployment.
```
web: bundle exec puma -p $PORT
```

##### Heroku config
The following additional config variables are required for Heroku (in addition to your SLACK_API_TOKEN)
```
heroku config:add GAME_BOARD_NAME=-your-boards-name
heroku config:add BOT_NAME=your-bots-name
heroku config:add SLACK_RUBY_BOT_SEND_GIFS=false
```

# Thanks/Aknowledgements
Thanks to [slack-ruby-bot](https://github.com/dblock/slack-ruby-bot) and it's developers/contributors for the heavy lifting regarding the bot's connection to Slack and first configuration.

Cards sourced from [nodanaonlyzuul/against-humanity](https://github.com/nodanaonlyzuul/against-humanity) and [samurailink3/hangouts-against-humanity](https://github.com/samurailink3/hangouts-against-humanity/wiki/Cards)


# License
Copyright (c) 2016 [Daniel Swain](http://www.danielcswain.com)

This project is licensed under the [MIT License](LICENSE.md).

# Warning :)
This is still a work in progress and is my first public for consumption repository, there will likely be bugs.
