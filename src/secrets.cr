require "./secrets/*"
require "kemal"
require "db"
require "sqlite3"
require "Digest"

SQLite = DB.open "sqlite3:./db/secrets.db"
at_exit { SQLite.close }

begin
	SQLite.exec "CREATE TABLE posts ( " \
				"id text PRIMARY KEY, " \
				"body text NOT NULL );"
rescue error : SQLite3::Exception
	unless error.message == "table posts already exists"
		raise error # Can't get SQLite3 to work with [IF NOT EXIT] or whatever it is.
	end
end

def store(text)
	hash = Digest::SHA1.digest(text).map(&.to_s(16)).join
	SQLite.exec "INSERT OR IGNORE INTO posts VALUES ( " \
				"'#{hash}', " \
				"'#{text}');"
end

get "/" do |env|
	render "src/views/landing.html.ecr", "src/views/layout.html.ecr"
end

post "/post" do |env|
	body =  env.params.body["post-body"]
	puts "Secret posted: " + body
	store body
	env.redirect "/"
end

get "/secret/:hash" do |env|
	hash = env.params.url["hash"]
	q = SQLite.query_one?("SELECT * FROM posts WHERE id=\'#{hash}\' LIMIT 1;", as: {String, String})
	if q.nil?
		env.response.status_code = 404
	else
		link = q[0]
		body = q[1]
		render "src/views/post.html.ecr", "src/views/layout.html.ecr"
	end
end

get "/secret" do |env|
	q = SQLite.query_one?("SELECT * FROM posts ORDER BY RANDOM() LIMIT 1;", as: {String, String})
	if q.nil?
		env.redirect "/"
	else
		link = q[0]
		body = q[1]
		render "src/views/post.html.ecr", "src/views/layout.html.ecr"
	end
end

Kemal.run
