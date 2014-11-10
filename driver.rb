require_relative 'data_access'
require_relative 'commands/author_search_command'
require_relative 'commands/number_of_copies_command'
require_relative 'commands/update_book_command'
require_relative 'commands/quit_command'
require_relative 'commands/add_book_command'
require_relative 'commands/delete_book_command'

 

database = DataBase.new ARGV[0]
remote_cache = Dalli::Client.new('localhost:11211')
data_source = DataAccess.new(database,remote_cache)
data_source.start

commands = [
	AuthorSearchCommand.new(data_source),  
	NumberOfCopiesCommand.new(data_source),
	UpdateBookCommand.new(data_source),
	AddBookCommand.new(data_source),
	DeleteBookCommand.new(data_source),
	QuitCommand.new(data_source)
]	
last_command = commands.size() -1

quit = false
puts
while !quit 
	commands.each_index do |index| 
		puts " #{index+1} #{commands[index].title}"
    end
    print "Which option? "  
	option = STDIN.gets.chomp.to_i
	option -= 1     # Adjust for array index 
	# puts "\e[H\e[2J"   # Clear screen (Unix/Mac only)
	if (0..last_command) === option
	   commands[option].input
	   commands[option].execute
	   20.times { print '-'}
	   puts
	 else
	    puts 'Not a valid opyion.'
	 end 
	 quit = true if option == last_command
end
