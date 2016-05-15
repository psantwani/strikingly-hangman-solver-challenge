require 'uri'
require 'net/http'
require 'json'

#Initialize global variables for each new game.
def gameReset
	#player details
	@player_id = "psantwani@gmail.com"
	@request_url = "https://strikingly-hangman.herokuapp.com/game/on"

	#game parameters
	@sessionId = ""
	@numberOfWords = 0
	@maxWrongCountAllowedPerWord = 0
	@overallWrongGuessCount = 0
	@finalScore = 0

	#api request parameters
	@uri = URI(@request_url)
	@request = Net::HTTP::Post.new @uri.path

	#count parameters
	@maxGuessesAllowedPerWord = 0
	@currentWordCount = 0	
	@wordsGuessedCorrectly = 0
end
	
#Initalize and reset global variables for every word in every game.
def wordReset	
	#progress tracking parameters			
	@overAllRightGuessCount = 0
	@strikesRemaing = 10

	#dictionary parameters
	@dictionary_url = "words.txt"
	@dictionary=File.open(@dictionary_url).read
	@dictionary.gsub!(/\r\n?/, " ")
	@probable_words = []
	@wordFrequency = {}

	#play parameters
	@guessWord = ""	
	@word_length = @guessWord.length
	@guess_letter = ""
	@guess_result = false
	@wrongGuessCount = 0
	@rightGuessCount = 0
	@totalGuessCountPerWord = 0
	@wordSelectorIndex = 0
	@word_list = ""
	@used_letters = []
	@lettersTobeGuessed = 0
end	

#launch game. Entry point of this ruby script.
def run
	gameReset
	wordReset
	puts "\n<< Welcome to the Hangman game. >>\n"		
	welcome		
end	

#Welcome message to the user. Asking the user to start the game.
def welcome
	user_action = ""
	until user_action == "quit"	 # Take input action from the user till he quits the game.
		puts "\nChoose an action from : startGame, getResult, submitResult, quit"
		print ("Enter action > ")
		user_action = gets.chomp.strip	
		gameReset	
		case user_action
			when "startGame"
				strikinglyApis("startGame")	
			when "getResult"	
				print("Enter session id > ")
				@sessionId = gets.chomp.strip
				strikinglyApis("getResult")
			when "submitResult"	
				print("Enter session id > ")
				@sessionId = gets.chomp.strip
				strikinglyApis("submitResult")
			when "quit"		
				puts "\n<< Thank you for playing. >>\n\n"
				break
			else
				puts "Invalid command. Try again."	
		end	
	end			
end

#Calling the strikingly APIs
def strikinglyApis(action = nil, letter = nil)

	case action
		when 'guessWord'
			@request.body = { :sessionId => @sessionId,
  				:action => "guessWord",
  				:guess => letter.upcase
  			}.to_json	
		when 'nextWord'
			@request.body = {
  				:sessionId => @sessionId,
  				:action => "nextWord"
			}.to_json	
		when 'startGame'
			@request.body = {
  				:playerId => @player_id,
  				:action => "startGame"
			}.to_json	
		when 'getResult'
			@request.body = {
  				:sessionId => @sessionId,
  				:action => "getResult"
			}.to_json	
		when 'submitResult'
			@request.body = {
				:sessionId => @sessionId,
  				:action => "submitResult"
			}.to_json	
		else
			puts "Could not understand command."
	end			
		
	res = Net::HTTP.start(@uri.host, @uri.port, :use_ssl => true) do |http|
    	http.request @request
	end
	response = JSON.parse(res.body)
	updateGame(response, action, letter)
end	

#updating game and progress parameters based on the Strikingly API response.
def updateGame(response, action, letter = nil)
	
	case action
		when 'guessWord'								
			nextGuess(response, letter)
		when 'nextWord'				
			wordReset	#Resetting global variables.
			@guessWord = response["data"]["word"]	#setting next word.
			@word_length = @guessWord.length
			@lettersTobeGuessed = @word_length
			@currentWordCount += 1
			puts "New word : " + @guessWord    			
    		filterByWordLength    			
		when 'startGame'				
			wordReset	#Resetting global variables.
			@sessionId = response["sessionId"]
    		@numberOfWords = response["data"]["numberOfWordsToGuess"]
    		@maxGuessesAllowedPerWord = response["data"]["numberOfGuessAllowedForEachWord"]	
    		puts response["message"]
			puts "Session Id : " + @sessionId.to_s	#Displaying game's session id.			
    		strikinglyApis("nextWord")
		when 'getResult'
			@numberOfWords = response["data"]["totalWordCount"].to_s
			@wordsGuessedCorrectly = response["data"]["correctWordCount"].to_s
			@overallWrongGuessCount = response["data"]["totalWrongGuessCount"].to_s
			@finalScore = response["data"]["score"].to_s	#getting final score
			farewell			
		when 'submitResult'
			@numberOfWords = response["data"]["totalWordCount"].to_s
			@wordsGuessedCorrectly = response["data"]["correctWordCount"].to_s
			@overallWrongGuessCount = response["data"]["totalWrongGuessCount"].to_s
			@finalScore = response["data"]["score"].to_s
			puts "Score submitted."
		else
			puts "Could not understand command."
	end			
end	

#Manipulate the response to the word guess.
def nextGuess(response, letter = nil)

	#The last guess is deemed right if the overall wrong guess count doesnt increase. 
	if @wrongGuessCount.to_i < response["data"]["wrongGuessCountOfCurrentWord"].to_i
		@guess_result = false
	elsif @wrongGuessCount.to_i == response["data"]["wrongGuessCountOfCurrentWord"].to_i
		@guess_result = true
	else
		@guess_result = false
	end	

	@guess_result = false if(letter == nil) else true	
	@guessWord = response["data"]["word"] #updating the guess word received from the API.
	puts "word after this guess : " + @guessWord #Displaying the new guess word.	
	@wrongGuessCount = response["data"]["wrongGuessCountOfCurrentWord"]
	@totalGuessCountPerWord = @totalGuessCountPerWord + 1

	if @guess_result
		puts "Match. Good going." #Displayed when the user guesses correctly.
		@lettersTobeGuessed = @lettersTobeGuessed - 1
		puts "---------------------------"
		@rightGuessCount += 1
		@wordSelectorIndex = 0
		@used_letters << letter					
		if(@guessWord.index("*") == nil)	
			@wordsGuessedCorrectly += 1
			answer
		else	
			updateDictionary(@guessWord)
		end	
	else
		@strikesRemaing = @strikesRemaing - 1
		puts "Wrong guess." # Displayed when the user commits a wrong guess.
		puts "---------------------------"
		if @strikesRemaing == 0
			puts "0 lives left. Going to the next word" # Displayed when number of wrong attempts per word exceeds the max allowable threshold.
			answer
		else
			@used_letters << letter
			@overallWrongGuessCount += 1
			@wordSelectorIndex += 1
			chooseWord		
		end
	end		
end	

#Narrow down the dictionary by selecting words that match the length of the word to be guessed.
def filterByWordLength	
	@dictionary.each_line do |line|
  		if line.length == (@word_length + 1)
  			@probable_words << (line.sub("\n",""))
  		end	
	end
	wordFrequencyCalculator
end	

#Calculating frequency of alphabets amongst the words in the dictonary and sorting them in the descending order of frequency.
def wordFrequencyCalculator
@wordFrequency = {}
@word_list = @probable_words.join("\n")
	for letter in ("a".."z")
		if not @used_letters.include? letter			
			indices = (0 ...@word_list.length).find_all { |i| @word_list[i,1] == letter }		
			@wordFrequency[letter] = indices.length					
		end
	end	
	@wordFrequency = Hash[@wordFrequency.sort_by{|k, v| v}.reverse]	
	chooseWord
end

#Choosing the letter with the maximum frequency from the hash created in the above method.
def chooseWord
	max_value = @wordFrequency.values[@wordSelectorIndex]	
	if max_value == 0 #If the maximum frequency is 0, it implies that the word does not exist in the dictionary.
			puts "Word not available in the dictionary."
			answer
		else
			high_freq_letters = (@wordFrequency.select { |key, value| value == max_value }).keys - @used_letters
			@guess_letter = high_freq_letters.sample	
			puts "Guess letter : " +  @guess_letter
			puts "Lives left : " + (@strikesRemaing).to_s
			strikinglyApis("guessWord", @guess_letter) #Submit the chosen letter to the API.
	end		
end	

#Update the dictionary to be scanned after a right guess has been made.
def updateDictionary(guessWord)
	guessWord = guessWord.downcase
	filterLetters = @used_letters.join()
	regex_formula = ""
	guessWord.split("").each do |i|
  		if i == "*"
  			regex_formula += "(?!["+filterLetters+"])[a-z]"
  		else
  			regex_formula += i
  		end  	
	end
	regex_formula += ""
	regex_formula = Regexp.new regex_formula  	
	@word_list = @probable_words.join(" ")	
	@word_list = @word_list.scan(regex_formula) #Using regex to scan words that match the current status of the guess word in terms of the positions of the letters.
	@word_list = @word_list.join("\n")
	@probable_words = []
	@word_list.each_line do |line|  		
  		@probable_words << line
	end
	wordFrequencyCalculator	
end	

#Display game status after every word.
def answer	
	puts "\nYour word is : " + @guessWord
	puts "You guessed " + @currentWordCount.to_s + " words in total."
	puts "You guessed " + @wordsGuessedCorrectly.to_s + " words correctly."
	puts "You have made " + @overallWrongGuessCount.to_s + " wrong gusesses in this game."	
	puts "---------------------------"	
	if (@currentWordCount == @numberOfWords)
		strikinglyApis("getResult")
	elsif (@currentWordCount < @numberOfWords)
		strikinglyApis("nextWord")
	end		
end

#Display final score and game statistics. Farewell.
def farewell
	puts "You guessed " + @numberOfWords.to_s + " words in total."
	puts "You guessed " + @wordsGuessedCorrectly.to_s + " words correctly."
	puts "You have made " + @overallWrongGuessCount.to_s + " wrong gusesses in this game."
	puts "Your Score is " + @finalScore.to_s
	print "Would you like to submit your score ? (y or n) > "
	user_action = gets.chomp.strip
	if user_action == "y"
		strikinglyApis("submitResult")
	end		
	puts "\n<< Thank you for playing. >>\n\n"
end	

#Call run
run
