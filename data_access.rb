require_relative 'book_in_stock'
require_relative 'database'
require 'dalli'

class DataAccess 
  $LocalCacheMaximumSize = 100

  def initialize (data_base,remote_cache) 
        @database = data_base
        @Remote_cache = remote_cache
        @localCache = {}
        @localCacheForcomplexData = {}
        # Relevant data structure(s) for local cache
  end  

  def getSimpleLocalCache
    @localCache
  end

  def getComplexLocalCache
    @localCacheForcomplexData
  end
  
  def start 
  	 @database.start 
  end

  def stop
  end

  def display_cache() 
    puts "Local simple cache:"
    @localCache.each {|k,v| puts "#{k} - #{v}"  }
  end 

  def localSimpleMemoryCheck
    display_cache
    if @localCache.size > $LocalCacheMaximumSize
      @localCache = {}
    end
  end
    
  def localComplexDataCheck
    display_complex_cache
    if @localCacheForcomplexData.size > $LocalCacheMaximumSize
      @localCacheForcomplexData = {}
    end
  end

  def display_complex_cache() 
    puts "Local complex cache:"
   @localCacheForcomplexData.each {|k,v| puts "#{k} - #{v}"  }
  end 

  def findISBNFromDatabase isbn
       book = @database.findISBN isbn
  end

  def findISBNFromServerCache isbn, version
    tempVersion = version
    if version   
       serial = @Remote_cache.get "#{version}_#{isbn}"
       book = BookInStock.from_cache serial
    else   # Not in cache, so add it.
       book = findISBNFromDatabase isbn
       if book
          tempVersion = 1
          @Remote_cache.set "v_#{book.isbn}",1  
          @Remote_cache.set "1_#{book.isbn}", book.to_cache
       end
    end 
    bookInfo = {:book => book, :version => tempVersion}      
  end

  def findISBNFromLocalCache isbn
    bookHash = @localCache["#{isbn}"]
    version = @Remote_cache.get "v_#{isbn}"
    if bookHash && version && bookHash[:version] == version
        book = bookHash[:book]
        localSimpleMemoryCheck
    else
      bookInfo = findISBNFromServerCache(isbn, version)
      book = bookInfo[:book]
      version = bookInfo[:version]
      if book
        bookHash = {:book => book, :version => version}
        @localCache["#{isbn}"] = bookHash
      end
    end
    book
  end

  def findISBN isbn
    book = findISBNFromLocalCache isbn      
  end

  def authorSearchFromServerCache author
    bksIsbnsAry = []
    booksInfoAry = []
    bskKeyAry = []
    books = []
    booksIsbns = ""

    booksIsbns = @Remote_cache.get "bks_#{author}"
    if booksIsbns && booksIsbns.length > 0
      booksIsbnsAry = booksIsbns.split(",")

      booksIsbnsAry.each do |isbn|
        version = @Remote_cache.get "v_#{isbn}"
        bskKeyAry << "#{isbn}_#{version}"
      end

      bsComplexKey = bskKeyAry.join(",")
      booksInfo = @Remote_cache.get "#{author}_#{bsComplexKey}"

      if booksInfo && booksInfo.length > 0
          booksInfo.split(";").each do |book|
          bookTemp = BookInStock.from_cache book
          books << bookTemp
        end
      else
        books = @database.authorSearch author
        books.each do |b|
          booksInfoAry << b.to_cache
        end
        booksInfo = booksInfoAry.join(";")
        @Remote_cache.set "#{author}_#{bsComplexKey}",booksInfo
      end
    else
      books = @database.authorSearch author
      if books          
        books.each do |b|
          booksInfoAry << b.to_cache
          bksIsbnsAry << b.isbn
          version = @Remote_cache.get "v_#{b.isbn}"
          if version
            bskKeyAry << "#{b.isbn}_#{version}"
          else
            @Remote_cache.set "v_#{b.isbn}",1  
            @Remote_cache.set "1_#{b.isbn}", b.to_cache
            bskKeyAry << "#{b.isbn}_1"
          end
        end
        booksIsbns = bksIsbnsAry.join(",")
        bsComplexKey = bskKeyAry.join(",")
        booksInfo = booksInfoAry.join(";")

        @Remote_cache.set "bks_#{author}",booksIsbns
        @Remote_cache.set "#{author}_#{bsComplexKey}",booksInfo
      end
    end
    if books.size > 0
       result = {:isbns => booksIsbns, :complexKey => bsComplexKey, :books => books}
    end
  end

  def authorSearchFromLocalCache author
    books = []
    bookHash = {}
    bookHash = @localCacheForcomplexData["bks_#{author}"]
    booksIsbns = @Remote_cache.get "bks_#{author}"
    complexKey = constructComplexKey booksIsbns

    puts bookHash
    puts booksIsbns
    puts complexKey

puts "%%%%%%%%%%%%%%%%"
    if bookHash && booksIsbns && bookHash[:isbns] == booksIsbns \
      && complexKey && complexKey == bookHash[:complexKey]
        books = bookHash[:books]
        localComplexDataCheck
              puts "sssssssssssss"

    else
      # puts "1111111111111"

      result = authorSearchFromServerCache author
      if result
              # puts "1111111111111"

        @localCacheForcomplexData["bks_#{author}"] = result
        books = result[:books] 
      else
        puts "here is not any book exist"
      end
    end
    books
  end

  def constructComplexKey booksIsbns
    if booksIsbns == nil
      return nil
    end
    bskKeyAry = []
    booksIsbnsAry = booksIsbns.split(",")
    booksIsbnsAry.each do |isbn|
      version = @Remote_cache.get "v_#{isbn}"
      if version
        bskKeyAry << "#{isbn}_#{version}"
      end
    end
    complexKey = bskKeyAry.join(",")
  end

  def authorSearch(author)
    authorSearchFromLocalCache author
  end

  def updateBookToLocalCache book, version
    bookInfo = @localCache["#{book.isbn}"]
    if bookInfo
      bookInfo[:book] = book
      bookInfo[:version] = version
    end
  end

  def updateBookToServerCache book
    version = @Remote_cache.get "v_#{book.isbn}"
    if version
      @Remote_cache.set "v_#{book.isbn}",version+1  
      @Remote_cache.set "#{version+1}_#{book.isbn}", book.to_cache
      updateBookToLocalCache book, version
    end
  end

  def updateBook book
   b = @database.findISBN book.isbn
   if b
     @database.updateBook book
    updateBookToServerCache book
   end
  end 

  def deleteComplexDataIsbns book
    booksIsbns = @Remote_cache.get "bks_#{book.author}"
    if booksIsbns
      booksIsbnsAry = booksIsbns.split(",")
      if booksIsbnsAry.include?(book.isbn)
        booksIsbnsAry.delete book.isbn
        booksIsbns = booksIsbnsAry.join(",")
        @Remote_cache.set "bks_#{book.author}",booksIsbns 
      end
    end
  end

  def deleteBookFromServerCache book
    version = @Remote_cache.get "v_#{book.isbn}"
    if version
      @Remote_cache.set "v_#{book.isbn}",nil 
      @Remote_cache.set "#{version+1}_#{book.isbn}", nil
    end
  end

  def deleteBookFromLocalCache book
    bookInfo = @localCache["#{book.isbn}"]
    if bookInfo
      @localCache["#{book.isbn}"] = nil
    end
  end

  def deleteBook isbn
    book = @database.findISBN isbn
    if book
       @database.deleteBook isbn
       deleteBookFromServerCache book
       deleteBookFromLocalCache book
       deleteComplexDataIsbns book
    else
      puts 'Invalid ISBN'
    end
  end 

  def addComplexDataIsbns book
    booksIsbns = @Remote_cache.get "bks_#{book.author}"
    if booksIsbns
      booksIsbns = booksIsbns + ",#{book.isbn}"
      @Remote_cache.set "bks_#{book.author}",booksIsbns 
      @Remote_cache.set "v_#{book.isbn}",1  
      @Remote_cache.set "1_#{book.isbn}", book.to_cache
    end
  end

  def addBook book
    b = @database.findISBN book.isbn
    if b
      puts "this book is exist"
    else
      @database.addBook book
      addComplexDataIsbns book
    end
  end
end 