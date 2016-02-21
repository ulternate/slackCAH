module SlackCAHBot
    module Commands

        class CAH < SlackRubyBot::Commands::Base
            #get sources folder, make it a variable for all commands
            @@source_path = File.expand_path("../../source", __FILE__)
            #Get the questions and answers from the sources files
            @@answers = File.foreach(@@source_path + '/answers.txt').map { |line| line }
            @@questions = File.foreach(@@source_path + '/questions.txt').map { |line| line }
            #Variables for player_hand, player_hands, current_players and last_question
            @@player_hand = Hash.new
            @@player_hands = []
            @@current_players = []
            @@last_question = nil
            @@card_czar = 0 #<-First element of the current_players array.
            @@game_board = ENV['GAME_BOARD_NAME'] #<- Channel id for the created c_a_h board
            @@wipbot_id = ENV['BOT_NAME'] #<- Wipbot user id placeholder.
            @@game_in_progress = false
            @@users_status = Hash.new #<-Have they already submitted this round?
            @@current_answers = Hash.new #<-What is the current submitted answers for each user?
            @@current_commands = {
                help: "List the commands that #{@@wipbot_id} takes.",
                start: "Start a game of Cards against humanity. Requires user objects to initiate game with selected players. The following format is expected: ```#{@@wipbot_id} start @user1 @user2...```",
                pick: "Select the current card(s) you'd like to play for the given question card. Card list is zero indexed so the first card is card[0]. The following format is expected: ```#{@@wipbot_id} pick 0 9```",
                showCards: "Show your current hand. This will show the 10 cards in your hand on your Direct Message (DM) page with #{@@wipbot_id}.",
                showQuestion: "Show the current question, in case you've forgotten.",
                showPlayed: "Show the final hands played by all players, useful if you've forgotten and need to pick a winner.",
                scores: "Show the current scores for all players. No arguments are expected.",
                winner: "Select the winning hand. This option will only work if the user is the current card czar. The following format is expected: ```#{@@wipbot_id} winner 0```",
                reset: "Reset the card decks and clear player hands. A call to 'start' is required to start again.",
                status: "See who we're waiting on to play their hand.",
                quit: "Quit the current game."
            }

            #List the commands available to the user
            command 'help' do |client, data|
                #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                #Send the help message
                message = "The following are the commands that #{@@wipbot_id} takes. Command calls are case insensitive.\n"
                @@current_commands.each {|k, v| message += "*#{k.to_s}* - #{v}\n"}
                client.say(channel: data.channel, text:message)
            end

            #Start a game of Cards Against Humanity
            #start requires addition data info like the users playing
            #If that is missing send an error to the message board.
            command 'start' do |client, data|
                if @@game_in_progress
                    #don't allow this call if the game is in progress.
                    #client.say(channel: @@game_board, text: "There's already a game in progress. Call *#{@@wipbot_id} quit*, or *#{@@wipbot_id} reset*.")
                    message = "There's already a game in progress. Call *#{@@wipbot_id} quit*, or *#{@@wipbot_id} reset*, before trying again."
                    client.say(channel: data.channel, text:message)
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #get the data_text and select only the current_players by removing the bot user id and the bot command
                    data_text = data.text.split(" ")
                    case
                    when data_text.length < 2
                        client.say(channel: data.channel, text: "You need to specify the users you'd like to play with. The format should be:\n```#{@@wipbot_id} start @user1 @user2...```")
                    when data_text.length >= 2
                        #Check to see if the users are valid, if so then continue the starting of the game
                        @@current_players = data_text.select { |s| s != @@wipbot_id && s.casecmp("start") != 0 && s != (@@wipbot_id + ":") }
                        all_user_ids = []
                        invalid_users = []
                        #Get all the user_id's for the channel and grab their id's
                        client.web_client.users_list()["members"].each{ |obj| all_user_ids << obj["id"] }
                        #if the user_id from the @@current_players array isn't in the all_user_ids then it's not a valid user
                        #We remove the <,@,> from the user_id as that's stored in @@current_players, but the all_user_ids are just the id without tags
                        @@current_players.each{ |user_id| invalid_users << user_id if !all_user_ids.include?(user_id.gsub(/[@<>]/,'')) }
                        if invalid_users.length > 0
                            #send the message to the board, there's invalid users trying to play
                            message = "The following users: *#{invalid_users.join(", ")}* are not actual users and the game was abandoned. Please enter valid player usernames (i.e. #{@@wipbot_id}) and try again."
                            client.say(channel: data.channel, text: message)
                        else
                            #create the initial players hand and fill it with cards from answers
                            #do this for each player
                            @@current_players.each do |uID|
                                @@player_hand[:points] = 0
                                @@player_hand[:user] = uID
                                10.times do |i|
                                    card = rand(0..@@answers.length)
                                    @@player_hand[i] = @@answers[card]
                                    @@answers.delete_at(card)
                                end
                                temp_hash = Hash[@@player_hand.map{ |k, v| [k, v]}]
                                @@player_hands << temp_hash
                                @@player_hand.clear
                            end

                            #ask the first question card, store it to last_question and delete from questions
                            quest = rand(0..@@questions.length)
                            @@last_question = @@questions[quest]
                            @@questions.delete_at(quest)
                            #push to game_board channel
                            start_message = "A game of Cards Against Humanity was started, cards have been dealt to your private boards, here's your first question.\n```#{@@last_question}```\nI've sent your initial hands to your private Direct Message (DM) boards, you can choose your card there, or here.\n Use *#{@@wipbot_id} pick 0 3* to play cards 0 and 3 from your hand." + "\n#{@@current_players[@@card_czar]} is the current Card czar, they will decide who wins round one."
                            client.say(channel: @@game_board, text: start_message)

                            #push message to users channel
                            msg_header = "A game of Cards Against Humanity was started.\nYou're playing with: "
                            msg_footer = "The current question is:\n ```#{@@last_question}``` \n Call *#{@@wipbot_id} pick 2* to pick your card(s), which in this case would be card 2."
                            @@player_hands.each {|hash| msg_header += hash[:user] + " "}
                            @@player_hands.each do |hash|
                                #Set the users status to false (i.e. they haven't picked their answer yet). But set it to true if they're the card_czar
                                @@current_players[@@card_czar] == hash[:user] ? @@users_status[hash[:user]] = true : @@users_status[hash[:user]] = false
                                #Get the user's hand
                                hand = ""
                                (0..9).each { |i| hand += "#{i}: #{hash[i]}\n" }
                                #open a DM, in case there isn't a DM between the user and the bot yet
                                client.web_client.im_open(
                                    "user": "#{hash[:user].gsub(/[@<>]/,'')}"
                                )
                                #Send the message using the WEB API Client as it's easier to DM.
                                client.web_client.chat_postMessage(
                                    "channel": hash[:user].gsub(/[@<>]/,''),
                                    "text": msg_header + "\nYour hand is \n```" + hand + "```\nYour points tally is: #{hash[:points]}.\n" + msg_footer,
                                    "as_user": true
                                )
                            end
                            #The game is now in progress
                            @@game_in_progress = true
                        end
                    end
                end

            end

            #Let the user play the card they want to play for the question.
            command 'pick' do |client, data|
                if @@game_in_progress
                    #You can't pick a card to play if you are the card czar
                    if @@current_players[@@card_czar].gsub(/[@<>]/,'') == data.user
                        message = "You can't pick a card this round as you are the card czar. Wait until notified to pick the winning hand."
                        client.say(channel: data.channel, text: message)
                    else
                        data_text = data.text.split(" ")
                        case
                        when data_text.length < 2
                            client.say(channel: data.channel, text: "You need to specify the card(s) you want to play, try the following command:\n```#{@@wipbot_id} pick 0 9```")
                        when data_text.length >= 2
                            #Check the cards being picked to ensure that the input information is correct
                            invalid_numbers = []
                            @cards_to_play = []
                            @cards_to_play = data_text.select { |s| s != @@wipbot_id && s.casecmp("pick") != 0 && s != (@@wipbot_id + ":") }
                            @cards_to_play.each{ |v| invalid_numbers << v.to_i if v.to_i > 9 }
                            duplicate_numbers = @cards_to_play.select{ |e| @cards_to_play.count(e) > 1 }.uniq
                            # If we have invalid numbers or duplicate numbers send a message to the channel the user called from.
                            if invalid_numbers.length > 0
                                message = "The card(s) you've chosen '#{invalid_numbers.join(", ")}' don't exist in your hand (Your hand contains 10 cards, numbered 0 to 9). Please try again."
                                @cards_to_play.clear
                                client.say(channel: data.channel, text: message)
                            elsif duplicate_numbers.length > 0
                                message = "You have chosen the following card(s) '#{duplicate_numbers.join(", ")}' more than once. Please try again but only selecting each card(s) once."
                                @cards_to_play.clear
                                client.say(channel: data.channel, text: message)
                            else
                                #User input is valid so lets store the selection for the player
                                @@player_hands.each do |hash|
                                    if hash[:user].gsub(/[@<>]/,'') == data.user
                                        message = ""
                                        if @@users_status[hash[:user]]
                                            message = "#{hash[:user]} has already played, you must wait for the card czar to select the winner before the next round begins."
                                        else
                                            @@users_status[hash[:user]] = true
                                            message = "You've played:\n"
                                            played_hand = ""
                                            @cards_to_play.each do |i|
                                                message += "```#{i}: #{hash[i.to_i]}```\n"
                                                played_hand += "```#{hash[i.to_i]}```\n"
                                            end
                                            @@current_answers[hash[:user]] = played_hand
                                            message += "\n#{@@current_players[@@card_czar]} will pick the winner once everyone has played.\nNew cards have been drawn for the one's you've played.\nCall *#{@wipbot_id} showCards* to see your new hand."

                                            #Draw the new cards for the player from the answers deck.
                                            @cards_to_play.length.times do |i|
                                                card = rand(0..@@answers.length)
                                                hash[@cards_to_play[i].to_i] = @@answers[card]
                                                @@answers.delete_at(card)
                                            end
                                        end
                                        #Start a DM with the player if one doesn't exist
                                        client.web_client.im_open(
                                            "user": "#{hash[:user].gsub(/[@<>]/,'')}"
                                        )
                                        #Send the DM with the hand the player played.
                                        client.web_client.chat_postMessage(
                                            "channel": hash[:user].gsub(/[@<>]/,''),
                                            "text": message,
                                            "as_user": true
                                        )
                                    end
                                end
                                #Clear the cards array
                                @cards_to_play.clear

                                # All users have played, lets send the selections to the game_board and the card_czar
                                if @@users_status.values.all? { |status| status == true }
                                    message = "All players have picked their card(s). #{@@current_players[@@card_czar]}, it's now your turn to pick one of the following card(s) that best answers the question.\n ```#{@@last_question}```"
                                    count = 0
                                    @@current_answers.each do |k, v|
                                        message += "\nHand number #{count}:\n #{v}"
                                        count += 1
                                    end
                                    #Send the message to the game board
                                    message += "\nTo select the winning hand enter *#{@@wipbot_id} winner n* where 'n' is the hand number as listed."
                                    client.say(channel: @@game_board, text: message)

                                    #Send the message to the DM of the card_czar
                                    client.web_client.im_open(
                                        "user": "#{@@current_players[@@card_czar].gsub(/[@<>]/,'')}"
                                    )
                                    #Send the DM with the hand the player played.
                                    client.web_client.chat_postMessage(
                                        "channel": @@current_players[@@card_czar].gsub(/[@<>]/,''),
                                        "text": message,
                                        "as_user": true
                                    )
                                end
                            end
                        end
                    end
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
            end

            #For each of the player_hands. If the user who requested it
            # has a hand then show it on their DM feed.
            command 'showCards' do |client, data|
                if @@game_in_progress
                    @@player_hands.each do |hash|
                        if hash[:user].gsub(/[@<>]/,'') == data.user
                            #Get the hand
                            hand = ""
                            (0..9).each { |i| hand += "#{i}: #{hash[i]}\n" }
                            #open a DM, in case there isn't a DM between the user and the bot yet
                            client.web_client.im_open(
                                "user": "#{hash[:user].gsub(/[@<>]/,'')}"
                            )
                            #Send the message using the WEB API Client as it's easier to DM.
                            client.web_client.chat_postMessage(
                                "channel": "#{hash[:user].gsub(/[@<>]/,'')}",
                                "text": "Your hand is:\n```" + hand + "```\nYour points tally is: #{hash[:points]}.",
                                "as_user": true
                            )
                        end
                    end
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
            end

            #Show the current question. Bot will respond on channel asked from.
            command 'showQuestion' do |client, data|
                if @@game_in_progress
                    client.say(channel: data.channel, text: "The current question is:\n```#{@@last_question}```\n")
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
            end

            #Show the played hands
            command 'showPlayed' do |client, data|
                if @@game_in_progress
                    #If we're waiting on the users hands then I won't post the played hands
                    waiting = false
                    @@users_status.each { |user, status| waiting = true if !status }
                    if waiting
                        message = "We're still waiting on some hands before you can see the hands played by everyone this round."
                    else
                        message = "Here are the hands played for:\n ```#{@@last_question}``` \n Call *#{@@wipbot_id} winner n* to select the best hand."
                        count = 0
                        @@current_answers.each do |k, v|
                            message += "\nHand number #{count}:\n #{v}"
                            count += 1
                        end
                        client.say(channel: data.channel, text: message)
                    end
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
            end

            #Show the players scores. Bot will respond on channel asked from.
            command 'scores' do |client, data|
                if @@game_in_progress
                    scores = "Here's the points tally as it stands.\n"
                    @@player_hands.each {|hash| scores += "#{hash[:user]}, total points = #{hash[:points]}.\n" }
                    client.say(channel: data.channel, text: scores)
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
            end

            #Select the winner if you're the card czar
            command 'winner' do |client, data|
                if @@game_in_progress
                    if @@current_players[@@card_czar].gsub(/[@<>]/,'') == data.user
                        data_text = data.text.split(" ")
                        case
                        when data_text.length < 2
                            client.say(channel: data.channel, text: "You need to specify the hand you want to select that wins this round, try the following command: ```#{@@wipbot_id} winner 0```")
                        when data_text.length >= 2
                            #Get and check the winning_position data
                            winning_position = data_text.select { |s| s != @@wipbot_id && s.casecmp("winner") != 0 && s != (@@wipbot_id + ":") }
                            if winning_position.length > 1
                                message = "You've chosen more than one winning hand, only one can be chosen. Please try again."
                                client.say(channel: data.channel, text: message)
                            elsif winning_position[0].to_i >= @@current_answers.length
                                message = "The number you've input '#{winning_position[0]}' doesn't represent a valid selection. Try again with one of the following valid selections: "
                                (0...@@current_answers.length).each { |n| message += "#{n} " }
                                client.say(channel: data.channel, text: message)
                            else
                                winning_user = @@current_answers.to_a[winning_position[0].to_i][0]
                                winning_hand = @@current_answers.to_a[winning_position[0].to_i][1]
                                @@player_hands.each { |hash| hash[:points] += 1 if hash[:user] == winning_user }
                                #put the results on the game_board and the users boards, and get the latest points totals.
                                message = "#{winning_user} had the best answer to the question:\n```#{@@last_question}```\nThey had the following hand:\n #{winning_hand}"
                                scores = "Here's the points tally as it stands after that round.\n"
                                @@player_hands.each { |hash| scores += "#{hash[:user]}, total points = #{hash[:points]}.\n" }

                                #get the next question card, store it to last_question and delete from questions
                                quest = rand(0..@@questions.length)
                                @@last_question = @@questions[quest]
                                @@questions.delete_at(quest)

                                #Set the next card_czar, starting back at zero if the last card_czar in the group played.
                                @@card_czar += 1
                                @@card_czar = 0 if @@card_czar == @@current_players.length

                                #Set the user status to true if they are the card_czar otherwise, set it to false
                                @@users_status.each{ |user, status| @@users_status[user] = false unless user == @@current_players[@@card_czar]}

                                #Clear the current selected hands so the old ones don't stay.
                                @@current_answers.clear

                                #Send the scores and the question to the game board and dm is it was asked there.
                                scores += "Ok, next round, the next question is:\n```#{@@last_question}```\n #{@@current_players[@@card_czar]} is the new card_czar."
                                if data.channel != @@game_board
                                    client.say(channel: @@game_board, text: message + scores)
                                    client.say(channel: data.channel, text: message + scores)
                                else
                                    client.say(channel: @@game_board, text: message + scores)
                                end
                            end
                        end
                    else
                        #Not the card_czar
                        message = "You're not the card_czar, #{@@current_players[@@card_czar]} is. You'll have to wait until they select the winner."
                        client.say(channel: data.channel, text: message)
                    end
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
            end

            #Reset the current game, need to pass it the users who will be playing
            command 'reset' do |client, data|
                if @@game_in_progress
                    #Clear the variables and prompt a recall of the start command.
                    @@answers.clear
                    @@questions.clear
                    @@answers = File.foreach(@@source_path + '/answers.txt').map { |line| line }
                    @@questions = File.foreach(@@source_path + '/questions.txt').map { |line| line }
                    @@player_hand.clear
                    @@player_hands.clear
                    @@current_players.clear
                    @@last_question = nil
                    @@card_czar = 0
                    @@game_in_progress = false
                    @@users_status.clear
                    @@current_answers.clear
                    #Send the reset message to the DM and group channel
                    message = "The game has been reset, the deck shuffled and ready to start again!\nCall *#{@@wipbot_id} start @user1 @user2...* to start a new game."
                    if data.channel != @@game_board
                        client.say(channel: @@game_board, text: message)
                        client.say(channel: data.channel, text: message)
                    else
                        client.say(channel: @@game_board, text: message)
                    end
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
            end

            #Status, will tell the group who we're waiting on and DM the users
            # Bot will respond on channel asked from for the time being.
            command 'status' do |client, data|
                if @@game_in_progress
                    #client.say(channel: data.channel, text: "This command is under construction!")
                    #Report the status of each user
                    waiting = false
                    message = "I'm waiting on the following players to select their card(s).\n\n"
                    @@users_status.each do |user, status|
                        if !status
                            waiting = true
                            message += "*#{user}* "
                            #send a DM to the user(s) we're waiting on
                            #open a DM, in case there isn't a DM between the user and the bot yet
                            client.web_client.im_open(
                                "user": "#{user.gsub(/[@<>]/,'')}"
                            )
                            #Send the message using the WEB API Client as it's easier to DM.
                            client.web_client.chat_postMessage(
                                "channel": "#{user.gsub(/[@<>]/,'')}",
                                "text": "The rest of the players are waiting on you to play your hand.",
                                "as_user": true
                            )
                        end
                    end
                    if waiting
                        # A message was sent to the players who were waiting, let the group know.
                        message += "\n\nI've sent a message to their Direct Message board to remind them to play."
                        if data.channel != @@game_board
                            client.say(channel: @@game_board, text: message)
                            client.say(channel: data.channel, text: message)
                        else
                            client.say(channel: @@game_board, text: message)
                        end
                    else
                        # None are waiting, send a message to the card_czar
                        message = "All players have played their hands, #{@@current_players[@@card_czar]} needs to pick the winner."
                        if data.channel != @@game_board
                            client.say(channel: @@game_board, text: message)
                            client.say(channel: data.channel, text: message)
                        else
                            client.say(channel: @@game_board, text: message)
                        end
                        # DM the card_czar. This could result in duplicate messages if the call is made from the card_czar's DM feed.
                        client.web_client.im_open(
                            "user": "#{@@current_players[@@card_czar].gsub(/[@<>]/,'')}"
                        )
                        client.web_client.chat_postMessage(
                            "channel": "#{@@current_players[@@card_czar].gsub(/[@<>]/,'')}",
                            "text": "The other players are waiting on you to select the winner of the round. call *#{@@wipbot_id} showPlayed* if you've forgotten what people played.",
                            "as_user": true
                        )
                    end
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
            end

            #Quit the current game
            # Bot will respond on channel asked from.
            command 'quit' do |client, data|
                if @@game_in_progress
                    #Clear the variables and send a cleared message.
                    @@answers.clear
                    @@questions.clear
                    @@answers = File.foreach(@@source_path + '/answers.txt').map { |line| line }
                    @@questions = File.foreach(@@source_path + '/questions.txt').map { |line| line }
                    @@player_hand.clear
                    @@player_hands.clear
                    @@current_players.clear
                    @@last_question = nil
                    @@card_czar = 0
                    @@users_status.clear
                    @@current_answers.clear
                    client.say(channel: data.channel, text: "The game has been stopped. Call *#{@@wipbot_id} help* for a reminder of the bot commands if you'd like to start a new one.")
                else
                    #Update the @@wipbot_id to contain the User_ID not the string from the .env file. Only if the id = the one in the ENV file
                    @@wipbot_id = "<@#{client.web_client.auth_test()["user_id"]}>" if @@wipbot_id == ENV['BOT_NAME']
                    # Grab the game board from the slack team using the board name (either public [channel] or private [group] )
                    client.web_client.channels_list()["channels"].each{ |chn| @@game_board = chn["id"] if chn["name"] == ENV['GAME_BOARD_NAME'] }
                    client.web_client.groups_list()["groups"].each{ |grp| @@game_board = grp["id"] if grp["name"] == ENV['GAME_BOARD_NAME'] }

                    #No game is in progress, tell the player
                    client.say(channel: data.channel, text: "There isn't a game in progress, call *#{@@wipbot_id} help* for a reminder of the bot commands.")
                end
                #Set the game_in_progress variable to false
                @@game_in_progress = false
            end
        end
    end
end
