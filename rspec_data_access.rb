require 'rspec/mocks'
require_relative './book_in_stock'
require_relative './data_access'

class Array
  def my_match_array (array)
    @tempArray1 = []
    @tempArray2 = []

    array.each do |book|
      bookInfo = book.to_cache
      @tempArray1 << bookInfo
    end
    self.each do |book|
      @tempArray2 << book.to_cache
    end

    @tempArray2.each do |b|
      if @tempArray1.include?(b) == false
        return false
      end
    end

    @tempArray1.each do |b|
      if @tempArray2.include?(b) == false
        return false
      end    
    end
    true
  end
end


describe DataAccess do
  before(:each) do
    @sqlite_database = double(:sqlite_database)
    @dalli_client = double(:dalli)
    @data_access = DataAccess.new(@sqlite_database,@dalli_client)
  end

  describe '#authorSearch' do
    before(:each) do
        @book1 = BookInStock.new("1111", "title1","author", "genre1", 11.1,11)
        @book2 = BookInStock.new("2222", "title2","author", "genre2", 22.2,22)
        @book3 = BookInStock.new("3333", "title3","author", "genre3", 33.3,33)
     end
   context "required book is not in the remote cache" do
        context "required book is also not in simple cache" do

         it "should get it from the database and put it in both caches" do
            expect(@dalli_client).to receive(:get).with('bks_author').and_return(nil)
            
            expect(@sqlite_database).to receive(:authorSearch).with('author').and_return([@book1, @book2])
            expect(@dalli_client).to receive(:get).with('v_1111').and_return(nil)
            expect(@dalli_client).to receive(:get).with('v_2222').and_return(nil)
            

            expect(@dalli_client).to receive(:set).with('bks_author','1111,2222')
            book1Info = @book1.to_cache
            book2Info = @book2.to_cache
            expect(@dalli_client).to receive(:set).with('author_1_1111,1_2222',"#{book1Info};#{book2Info}")

            expect(@dalli_client).to receive(:set).with('v_1111',1)
            expect(@dalli_client).to receive(:set).with('1_1111',@book1.to_cache)
            expect(@dalli_client).to receive(:set).with('v_2222',1)
            expect(@dalli_client).to receive(:set).with('1_2222',@book2.to_cache)
            @result = @data_access.authorSearchFromServerCache('author') 
            expect(@result[:books]).to match_array [@book1,@book2]
         end
       end

        context "required book in simple cache" do
         it "should get it from the database and only put it in complex caches" do
            expect(@dalli_client).to receive(:get).with('bks_author').and_return(nil)
            expect(@sqlite_database).to receive(:authorSearch).with('author').and_return([@book1, @book2])
            expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
            expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)
            expect(@dalli_client).to receive(:set).with('bks_author','1111,2222')
            book1Info = @book1.to_cache
            book2Info = @book2.to_cache
            expect(@dalli_client).to receive(:set).with('author_1_1111,1_2222',"#{book1Info};#{book2Info}")
            # expect(@dalli_client).to_not receive(:set)
            @result = @data_access.authorSearchFromServerCache('author') 
            # expect(@result[:books]).to match_array [@book1,@book2]
            expect(@result[:books].my_match_array([@book1,@book2])).to be true 
         end
       end
      end
    context "required book is in the remote cache but not in the local cache" do
       context "the data is valaible" do
          it "should ignore the database and get it from the remote cache" do
            expect(@sqlite_database).to_not receive(:authorSearch)
            expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')

            expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
            expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)

            book1Info = @book1.to_cache
            book2Info = @book2.to_cache
            expect(@dalli_client).to receive(:get).with('author_1_1111,1_2222').and_return("#{book1Info};#{book2Info}")

            @result = @data_access.authorSearchFromServerCache('author')
            expect(@result[:books].my_match_array([@book1,@book2])).to be true
            # expect(@result[:books]).to match_array [@book1,@book2]
          end
       end

       context "the data is not valaible,because someone add a book" do
          it "should update the date from database,and put is to complex cache" do
            expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222,3333')
            expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
            expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)
            expect(@dalli_client).to receive(:get).with('v_3333').and_return(1)
            expect(@dalli_client).to receive(:get).with('author_1_1111,1_2222,1_3333').and_return(nil)
            expect(@sqlite_database).to receive(:authorSearch).and_return([@book1,@book2,@book3])
            book1Info = @book1.to_cache
            book2Info = @book2.to_cache
            book3Info = @book3.to_cache
            expect(@dalli_client).to receive(:set).with('author_1_1111,1_2222,1_3333',"#{book1Info};#{book2Info};#{book3Info}")
            @result = @data_access.authorSearchFromServerCache('author')
            expect(@result[:books].my_match_array([@book1,@book2,@book3])).to be true
          end
       end

       context "the data is not valaible,because somebook updated" do
         before(:each) do
             @book1.quantity = 5
         end
          it "should update the date from database,and put is to complex cache" do
            expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222,3333')
            expect(@dalli_client).to receive(:get).with('v_1111').and_return(2)
            expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)
            expect(@dalli_client).to receive(:get).with('v_3333').and_return(1)
            expect(@dalli_client).to receive(:get).with('author_2_1111,1_2222,1_3333').and_return(nil)
            expect(@sqlite_database).to receive(:authorSearch).and_return([@book1,@book2,@book3])
            book1Info = @book1.to_cache
            book2Info = @book2.to_cache
            book3Info = @book3.to_cache
            expect(@dalli_client).to receive(:set).with('author_2_1111,1_2222,1_3333',"#{book1Info};#{book2Info};#{book3Info}")
            @result = @data_access.authorSearchFromServerCache('author')
            expect(@result[:books].my_match_array([@book1,@book2,@book3])).to be true
          end
       end
     end

    context "required book is in the local cache and is available" do
      before(:each) do
        expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')
        expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
        expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)
        bookInfo = {:isbns => '1111,2222', :complexKey => '1_1111,1_2222', :books => [@book1, @book2]}
        expect(@data_access).to receive(:authorSearchFromServerCache).with('author').and_return(bookInfo)
        @result = @data_access.authorSearch('author') 
       end
      it "should get it from the local cache" do
        expect(@data_access).to_not receive(:authorSearchFromServerCache)
        expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')
        expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
        expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)
        @result = @data_access.authorSearch('author') 
        expect(@result.my_match_array([@book1,@book2])).to be true
      end
      context "required book is in the local cache but is out-of-date because some book updated" do
        before(:each) do
          @book1.quantity = 5
        end
        it "should get it from the servercache" do
          
          expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')
          expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
          expect(@dalli_client).to receive(:get).with('v_2222').and_return(2)
          bookInfo = {:isbns => '1111,2222', :complexKey => '2_1111,1_2222', :books => [@book1, @book2]}
          expect(@data_access).to receive(:authorSearchFromServerCache).with('author').and_return(bookInfo)

          @result = @data_access.authorSearch('author') 
          expect(@result.my_match_array([@book1,@book2])).to be true
        end
      end

      context "required book is in the local cache but is out-of-date because some book added" do
        it "should get it from the servercache" do
          expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')
          expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
          expect(@dalli_client).to receive(:get).with('v_2222').and_return(2)
          bookInfo = {:isbns => '1111,2222,3333', :complexKey => '1_1111,1_2222,1_3333', :books => [@book1, @book2,@book3]}
          expect(@data_access).to receive(:authorSearchFromServerCache).with('author').and_return(bookInfo)
          @result = @data_access.authorSearch('author') 
          expect(@result.my_match_array([@book1,@book2,@book3])).to be true
        end
      end
    end

# ************************************** complex memory clear test
    context "required book is in the complex local cache 
            but local cache beyond the maxsize, so it is cleared and 
            should be get from servercache" do
      before(:each) do
        bookAry = []
        isbns = []
        complexKeys = []
        @books = []
# add a number of book to local cache and make it to beyond the maxisize

        for i in 1..10
          isbn = String(i)

          isbns << isbn
          complexKeys << "#1_{isbn}"
          expect(@dalli_client).to receive(:get).with("v_#{isbn}").and_return(1)
          book = BookInStock.new("#{isbn}", "title1","author", "genre1", 11.1,11)
          @books << book
        end

        @isbnsStr = isbns.join(",")
        @complexKeyStr = complexKeys.join(",")

        expect(@dalli_client).to receive(:get).with('bks_author').and_return(@isbnsStr)
        @bookInfo = {:isbns => @isbnsStr, :complexKey => @complexKeyStr, :books => @books}
        expect(@data_access).to receive(:authorSearchFromServerCache).with('author').and_return(@bookInfo)
        @result = @data_access.authorSearch('author') 
     end
      it "should get it from the servercache" do
        expect(@dalli_client).to receive(:get).with('bks_author').and_return(@isbnsStr)
        puts @isbns
        for i in 1..10
          isbn = String(i)
          expect(@dalli_client).to receive(:get).with("v_#{isbn}").and_return(1)
        end
        bookInfo = {:isbns => @isbnsStr, :complexKey => @complexKeyStr, :books => @books}
        expect(@data_access).to receive(:authorSearchFromServerCache).with('author').and_return(bookInfo)
        @result = @data_access.authorSearch('author') 
        expect(@result.my_match_array(@books)).to be true
      end
    end

context "required book is in the complex local cache 
            and did not beyond the maxsize, so it is available" do
    before(:each) do
        bookAry = []
        isbns = []
        complexKeys = []
        @books = []
              # add a number of book to local cache but it is not beyond the maxisize
        for i in 1..3
          isbn = String(i)

          isbns << isbn
          complexKeys << "1_#{isbn}"
          expect(@dalli_client).to receive(:get).with("v_#{isbn}").and_return(1)
          book = BookInStock.new("#{isbn}", "title1","author", "genre1", 11.1,11)
          @books << book
        end

        @isbnsStr = isbns.join(",")
        @complexKeyStr = complexKeys.join(",")

        expect(@dalli_client).to receive(:get).with('bks_author').and_return(@isbnsStr)
        @bookInfo = {:isbns => @isbnsStr, :complexKey => @complexKeyStr, :books => @books}
        expect(@data_access).to receive(:authorSearchFromServerCache).with('author').and_return(@bookInfo)
        @result = @data_access.authorSearch('author') 
     end
      it "should not to be got it from the servercache" do
        expect(@dalli_client).to receive(:get).with('bks_author').and_return(@isbnsStr)
        puts @isbns
        for i in 1..3
          isbn = String(i)
          expect(@dalli_client).to receive(:get).with("v_#{isbn}").and_return(1)
        end
        expect(@data_access).to_not receive(:authorSearchFromServerCache)
        @result = @data_access.authorSearch('author') 
        expect(@result.my_match_array(@books)).to be true
      end
    end
  end

  describe '#updateBook' do
   context "updateBook a book to database" do
    before(:each) do
        @book1 = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
        @book2 = BookInStock.new("1111", "title1","author1", "genre1", 11.3,15)
     end
     context "if the book is exist" do
       it "update it to database as well as change comlexDataIsbns" do
        expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(@book1)
        expect(@sqlite_database).to receive(:updateBook).with(@book2)
        expect(@data_access).to receive(:updateBookToServerCache)
        @data_access.updateBook @book2
       end
       context "if the book is in the server" do
         it "is update to server cache then add to local cache" do
          expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
          expect(@dalli_client).to receive(:set).with('v_1111',2)
          expect(@dalli_client).to receive(:set).with('2_1111',@book2.to_cache)
          expect(@data_access).to receive(:updateBookToLocalCache).with(@book2,2)
          @data_access.updateBookToServerCache @book2
         end
       end
       context "if the book is not in the server" do
         it "is not further action" do
          expect(@dalli_client).to receive(:get).with('v_1111').and_return(nil)
          expect(@dalli_client).to_not receive(:set)
          expect(@dalli_client).to_not receive(:set)
          expect(@data_access).to_not receive(:updateBookToLocalCache)
          @data_access.updateBookToServerCache @book2
         end
       end
     end

     context "if the book is not exist" do
       it "is not further action" do
        expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(nil)
        expect(@sqlite_database).to_not receive(:updateBook)
        expect(@data_access).to_not receive(:updateBookToServerCache)
        @data_access.updateBook @book2
       end
     end
    end
  end


  describe '#addBook' do
   context "add a book to database" do
    before(:each) do
        @book1 = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
        @book2 = BookInStock.new("2222", "title2","author1", "genre2", 22.2,22)

     end
     context "add a book to database if the book is not exist" do
       it " be add to database" do
        expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(nil)
        expect(@sqlite_database).to receive(:addBook)
        expect(@data_access).to receive(:addComplexDataIsbns)
        @data_access.addBook @book1
       end
       context "if the this author in complex add the information to complex data index" do
         it " be add to complex data index" do
            expect(@dalli_client).to receive(:get).with('bks_author1').and_return('1111')
            expect(@dalli_client).to receive(:set).with('bks_author1','1111,2222')
            expect(@dalli_client).to receive(:set).with('v_2222',1)
            expect(@dalli_client).to receive(:set).with('1_2222',@book2.to_cache)
            @data_access.addComplexDataIsbns(@book2) 
         end
        end
     end
      context "if the book is exist" do
        it "not more action" do
          expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(@book1)
          expect(@sqlite_database).to_not receive(:addBook)
          expect(@data_access).to_not receive(:addComplexDataIsbns)
          @data_access.addBook @book1
        end
      end
    end
  end

  describe '#deleteBook' do
   context "delete a book " do
    before(:each) do
        @book1 = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
        @book2 = BookInStock.new("2222", "title2","author1", "genre2", 22.2,22)

     end
      context "delete a book if the book is exist" do
       it "check if this book is exist then delete it from database and cache" do
        expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(@book1)
        expect(@sqlite_database).to receive(:deleteBook)
        expect(@data_access).to receive(:deleteBookFromServerCache)
        expect(@data_access).to receive(:deleteBookFromLocalCache)
        expect(@data_access).to receive(:deleteComplexDataIsbns)
        @data_access.deleteBook('1111') 
       end
         context "delete a book from remote simple cache" do
            it "delete a book from remote simple cache" do
            expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
            expect(@dalli_client).to receive(:set).with('v_1111',nil)
            expect(@dalli_client).to receive(:set).with('1_1111',nil)
            @data_access.deleteBookFromServerCache(@book1) 
           end
         end
         context "delete a book from remote complex cache" do
          it "delete a book from remote complex cache" do
            expect(@dalli_client).to receive(:get).with('bks_author1').and_return('1111,2222')
            expect(@dalli_client).to receive(:set).with('bks_author1','2222')
            @data_access.deleteComplexDataIsbns(@book1) 
          end
         end
    end
      context "delete a book if the book is not exist" do
       it "check if this book is not exist then no further action" do
        expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(nil)
        expect(@sqlite_database).to_not receive(:deleteBook)
        expect(@data_access).to_not receive(:deleteBookFromServerCache)
        expect(@data_access).to_not receive(:deleteBookFromLocalCache)
        expect(@data_access).to_not receive(:deleteComplexDataIsbns)
        @data_access.deleteBook('1111') 
      end
      end
    end
  end

  describe '#findISBN' do
     before(:each) do
        @book1 = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
        @book2 = BookInStock.new("2222", "title2","author2", "genre2", 22.2,22)
     end
     context "required book is not in the remote cache" do
         it "should get it from the database and put it in both caches" do
            expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(@book1)
            expect(@dalli_client).to receive(:set).with('v_1111',1)
            expect(@dalli_client).to receive(:set).with('1_1111',@book1.to_cache)
            @result = @data_access.findISBNFromServerCache('1111', nil) 
            expect(@result[:book]).to eql @book1    
         end
      end
    context "required book is in the remote cache" do
       context "but not in the local cache" do
          it "should ignore the database and get it from the remote cache" do
              expect(@sqlite_database).to_not receive(:findISBN)
              expect(@dalli_client).to receive(:get).with('1_1111').and_return(@book1.to_cache)
              @result = @data_access.findISBNFromServerCache('1111', 1) 
              expect(@result[:book]).to eql @book1  
          end
       end
     end
     context "and also in the local cache" do
       before(:each) do
         expect(@dalli_client).to receive(:get).with('v_1111').and_return(3)
         expect(@dalli_client).to receive(:get).with('3_1111').and_return  @book1.to_cache
         @result = @data_access.findISBN('1111') 
       end
       it "uses the local cache's entry" do
          expect(@dalli_client).to receive(:get).with('v_1111').and_return(3)
          expect(@data_access).to_not receive(:findISBNFromServerCache)
          @result = @data_access.findISBN('1111') 
          expect(@result).to eql @book1  
       end
       context "but the local cache is out-of-date" do
           before(:each) do
               @book1.quantity = 5
           end
           it "uses the remote cache's newer version" do
               expect(@dalli_client).to receive(:get).with('v_1111').and_return(4)
               bookHash = {:book => @book1, :version => 4}
               expect(@data_access).to receive(:findISBNFromServerCache).with('1111', 4).and_return bookHash
               @result = @data_access.findISBN('1111') 
               expect(@result).to eql @book1  
           end
       end             
    end
# ************************************** simple memory clear test
    context "required book is in the simple local cache 
            but local cache beyond the maxsize, so it is cleared and 
            should be get from servercache" do
      before(:each) do
        # add a number of book to local cache and make it beyond the maxisize
        for i in 1111..1122
          isbn = String(i)
          book = BookInStock.new(isbn, "title1","author1", "genre1", 11.1,11)
          expect(@dalli_client).to receive(:get).with("v_#{isbn}").and_return(1)
          expect(@dalli_client).to receive(:get).with("1_#{isbn}").and_return  book.to_cache
          @result = @data_access.findISBN("#{isbn}") 
        end
     end
      it "uses the local cache's entry" do
          expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
          book = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
          bookHash = {:book => book, :version => 1}
          expect(@data_access).to receive(:findISBNFromServerCache).with('1111', 1).and_return bookHash
          @result = @data_access.findISBN('1111') 
          expect(@result).to eql @book1  
       end
    end
context "required book is in the simple local cache 
            but local cache not beyond the maxsize, so it is cleared and 
            should be get from servercache" do
    before(:each) do
              # add a number of book to local cache but it is not beyond the maxisize
        for i in 1111..1114
          isbn = String(i)
          book = BookInStock.new(isbn, "title1","author1", "genre1", 11.1,11)
          expect(@dalli_client).to receive(:get).with("v_#{isbn}").and_return(1)
          expect(@dalli_client).to receive(:get).with("1_#{isbn}").and_return  book.to_cache
          @result = @data_access.findISBN("#{isbn}") 
        end
     end
      it "should not to be got it from the servercache" do
          expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
          book = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
          bookHash = {:book => book, :version => 1}
          expect(@data_access).to_not receive(:findISBNFromServerCache)
          @result = @data_access.findISBN('1111') 
          expect(@result).to eql @book1  
       end
    end
  end
end