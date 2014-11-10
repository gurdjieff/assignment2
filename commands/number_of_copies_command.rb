require_relative 'user_command'

class NumberOfCopiesCommand < UserCommand

	def initialize (data_source)
		super (data_source)
		@isbn = ''
	end

	def title 
		'Check no. of copies in stock'
	end

   def input
		puts 'No. of copies.'
		print "ISBN? "   
		@isbn = STDIN.gets.chomp  
   end

    def execute
    	result = @data_source.findISBN(@isbn)
    	if result
    	   puts "No. of copies = #{result.quantity}"
    	else
    		puts "Invalid ISBN"
    	end
	end

end