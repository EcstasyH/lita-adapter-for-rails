require "spec_helper"
require "sqlite3"
describe Lita::Adapters::Railschatbot, lita: true do
    let(:robot){Lita::Robot.new(registry)}
    subject{described_class.new(robot)}
    
    describe 'set read id  ' do 
        it 'initialize with right information' do
            u_r = subject.uid_rid

            expect(u_r.is_a?(Array)).to eq true
            expect(u_r[0].is_a?(Integer)).to eq true
            expect(u_r[1].is_a?(Integer)).to eq true
        end
    end

    describe 'database operations' do 
        it 'open database' do
            db = subject.open_database("development.sqlite3")
            a = db.execute "SELECT * FROM users" 
            
            expect(a[0][0]).to eq 1
            expect(a[0][1]).to eq "user1@test.com"
        end

        it 'close database' do
            db = subject.open_database("development.sqlite3")
            expect(db.closed?).to eq false
            db = subject.close_database
            expect(db.closed?).to eq true
        end
       
        it 'write database' do 
            db = subject.open_database("development.sqlite3")
            test_str = "test write"
            subject.write_database(db, test_str)
            a = db.execute "SELECT * FROM messages"
            
            expect(a[-1][1]).to eq test_str
            db = subject.close_database
        end

        it 'read message' do
            db = subject.open_database("development.sqlite3")
            to_read = 10
            a = subject.read_database(db, to_read-1)
            
            expect(a[0]["id"]).to eq to_read
            db = subject.close_database
        end
    end
end
