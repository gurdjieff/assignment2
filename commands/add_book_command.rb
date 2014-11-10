require_relative 'user_command'

class AddBookCommand < UserCommand

	def initialize (data_source)
		super (data_source)
		@isbn = ''
	end

	def title 
		'Add Book.'
	end

  def input
   	 puts 'Add Book.'
  end

  def execute
      puts "please input ISBN"   
      response1 = STDIN.gets.chomp 

      puts "please input title"   
      response2 = STDIN.gets.chomp 

      puts "please input author"   
      response3 = STDIN.gets.chomp 

      puts "please input genre"
      $GENRE.each_index {|i| print " (#{i+1}) #{$GENRE[i]} "}
      print ' ? '
      temp = STDIN.gets.chomp.to_i 
      response4 = $GENRE[temp - 1] if (1..$GENRE.length).member? temp 

      puts "please input price"  
      response5 = STDIN.gets.chomp 

      puts "please input quantity"  
      response6 = STDIN.gets.chomp 


    if response5.to_f && response6.to_i && response1.length > 0 && \
      response2.length > 0 && response3.length > 0

      book = BookInStock.new(response1, response2, \
        response3,response4,response5.to_f,response6.to_i)
      @data_source.addBook book
    else
      puts "text of input is invalid"  
    end
      
	end 

end
