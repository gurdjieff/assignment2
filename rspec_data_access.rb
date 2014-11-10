require 'rspec/mocks'
require_relative './book_in_stock'
require_relative './data_access'

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
     end
   context "required book is not in the remote cache" do
     
         it "should get it from the database and put it in both caches" do
            expect(@sqlite_database).to receive(:authorSearch).with('author').and_return([@book1, @book2])
            expect(@dalli_client).to receive(:get).with('bks_author').and_return(nil)
            
            expect(@dalli_client).to receive(:get).with('v_1111').and_return(nil)
            expect(@dalli_client).to receive(:get).with('v_2222').and_return(nil)

            expect(@dalli_client).to receive(:set).with('bks_author','1111,2222')
            book1Info = @book1.to_cache
            book2Info = @book2.to_cache
            expect(@dalli_client).to receive(:set).with('author_1111_1,2222_1',"#{book1Info};#{book2Info}")

            expect(@dalli_client).to receive(:set).with('v_1111',1)
            expect(@dalli_client).to receive(:set).with('1_1111',@book1.to_cache)
            expect(@dalli_client).to receive(:set).with('v_2222',1)
            expect(@dalli_client).to receive(:set).with('1_2222',@book2.to_cache)

            @result = @data_access.authorSearchFromServerCache('author') 
            expect(@result[:books].size).to eql 2
         end
      end
    context "required book is in the remote cache" do
       context "but not in the local cache" do
          it "should ignore the database and get it from the remote cache" do
            expect(@sqlite_database).to_not receive(:authorSearch)
            expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')

            expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
            expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)

            book1Info = @book1.to_cache
            book2Info = @book2.to_cache
            expect(@dalli_client).to receive(:get).with('author_1111_1,2222_1').and_return("#{book1Info};#{book2Info}")

            @result = @data_access.authorSearchFromServerCache('author') 
            expect(@result[:books].size).to eql 2
          end
       end

       context "but out-of-date" do
          before(:each) do
               @book1.quantity = 5
           end
          it "should get it from the database again" do
            expect(@sqlite_database).to receive(:authorSearch).with('author').and_return([@book1, @book2])
            expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')
            
            expect(@dalli_client).to receive(:get).with('v_1111').and_return(2)
            expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)

            book1Info = @book1.to_cache
            book2Info = @book2.to_cache
            expect(@dalli_client).to receive(:get).with('author_1111_2,2222_1').and_return(nil)
            expect(@dalli_client).to receive(:set).with('author_1111_2,2222_1',"#{book1Info};#{book2Info}")

            @result = @data_access.authorSearchFromServerCache('author') 
            expect(@result[:books].size).to eql 2
          end
       end
     end

    context "required book is in the local cache and is available" do
      before(:each) do
        expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')
        expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
        expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)
        bookInfo = {:isbns => '1111,2222', :complexKey => '1111_1,2222_1', :books => [@book1, @book2]}
        expect(@data_access).to receive(:authorSearchFromServerCache).with('author').and_return(bookInfo)
        @result = @data_access.authorSearch('author') 
       end
      it "should get it from the local cache" do
        expect(@data_access).to_not receive(:authorSearchFromServerCache)
        expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')
        expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
        expect(@dalli_client).to receive(:get).with('v_2222').and_return(1)
        
        @result = @data_access.authorSearch('author') 
        expect(@result.size).to eql 2
      end
      context "required book is in the local cache but is out-of-date" do
        before(:each) do
          @book1.quantity = 5
        end
        it "should get it from the local cache" do
          bookInfo = {:isbns => '1111,2222', :complexKey => '1111_2,2222_1', :books => [@book1, @book2]}
          expect(@data_access).to receive(:authorSearchFromServerCache).with('author').and_return(bookInfo)

          expect(@dalli_client).to receive(:get).with('bks_author').and_return('1111,2222')
          expect(@dalli_client).to receive(:get).with('v_1111').and_return(1)
          expect(@dalli_client).to receive(:get).with('v_2222').and_return(2)
          @result = @data_access.authorSearch('author') 
          expect(@result.size).to eql 2
        end
      end
    end
  end

  describe '#updateBook' do
   context "updateBook a book to database" do
    before(:each) do
        @book1 = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
        @book2 = BookInStock.new("1111", "title1","author1", "genre1", 11.3,15)
     end
     it "check if this book is exist then add to database as well as change comlexDataIsbns" do
      expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(@book1)
      expect(@sqlite_database).to receive(:updateBook).with(@book2)
      expect(@data_access).to receive(:updateBookToServerCache)
      @data_access.updateBook @book2
     end
    end
  end

  describe '#addBook' do
   context "add a book to database" do
    before(:each) do
        @book1 = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
     end
     it "check if this book is exist then add to database as well as change comlexDataIsbns" do
      expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(nil)
      expect(@sqlite_database).to receive(:addBook)
      expect(@data_access).to receive(:addComplexDataIsbns)
      @data_access.addBook @book1
     end
    end
  end

  describe '#deleteBook' do
   context "delete a book " do
    before(:each) do
        @book1 = BookInStock.new("1111", "title1","author1", "genre1", 11.1,11)
     end
       it "check if this book is exist then delete it from database and cache" do
        expect(@sqlite_database).to receive(:findISBN).with('1111').and_return(@book1)
        expect(@sqlite_database).to receive(:deleteBook)
        expect(@data_access).to receive(:deleteBookFromServerCache)
        expect(@data_access).to receive(:deleteBookFromLocalCache)
        expect(@data_access).to receive(:deleteComplexDataIsbns)
        @data_access.deleteBook('1111') 
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
            expect(@dalli_client).to receive(:get).with('v_1111').and_return(nil)
            expect(@dalli_client).to receive(:set).with('v_1111',1)
            expect(@dalli_client).to receive(:set).with('1_1111',@book1.to_cache)
            @result = @data_access.findISBN('1111') 
            expect(@result).to eql @book1    
         end
      end
    context "required book is in the remote cache" do
       context "but not in the local cache" do
          it "should ignore the database and get it from the remote cache" do
              expect(@sqlite_database).to_not receive(:findISBN)
              expect(@dalli_client).to receive(:get).with('v_1111').and_return(2)
              expect(@dalli_client).to receive(:get).with('2_1111').and_return  @book1.to_cache
              @result = @data_access.findISBN('1111') 
              expect(@result).to eql @book1  
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
          @result = @data_access.findISBN('1111') 
          expect(@result).to eql @book1  
       end
       context "but the local cache is out-of-date" do
           before(:each) do
               @book1.quantity = 5
           end
           it "uses the remote cache's newer version" do
               expect(@dalli_client).to receive(:get).with('v_1111').and_return(4)
               expect(@dalli_client).to receive(:get).with('4_1111').and_return  @book1.to_cache
               @result = @data_access.findISBN('1111') 
               expect(@result).to eql @book1  
           end
       end             
    end
  end
end