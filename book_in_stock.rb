class BookInStock      
  $GENRE = ['Programming', 'Web Development','S/w Engineering']
  attr_accessor :price, :title, :author, :genre, :quantity,:isbn
  attr_reader :isbn
  
  def initialize(isbn, title, author, genre, price, quantity)
    @isbn  = isbn
    @title = title
    @price = Float(price)
    @author = author
    @genre = genre
    @quantity = quantity
  end  

  def to_s
    "#{@title} by #{@author} (#{@isbn}) - #{@genre} - #{@quantity} copies - $ #{@price}"
  end

  def to_cache
     "#{@isbn},#{@title},#{@author},#{@genre},#{@price},#{@quantity}"
  end

  def self.from_cache serialized
      fields = serialized.split(',')

      BookInStock.new fields[0], fields[1], fields[2], 
                 fields[3], fields[4], fields[5].to_i
  end

  def eql?(other)
      return false  unless other.class.name == 'BookInStock'
      return (@isbn == other.isbn) && (@title == other.title) &&
             (@author == other.author) &&  (@genre == other.genre) &&
             (@price == other.price) && (@quantity == other.quantity)
  end

end