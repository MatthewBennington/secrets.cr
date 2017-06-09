require "./secrets/*"
require "kemal"
require "db"
require "sqlite3"
require "Digest"

SQLite = DB.open "sqlite3:./db/secrets.db"
at_exit { SQLite.close }

def store_post(text)
	hash = Digest::SHA1.digest(text).map(&.to_s(16)).join
	SQLite.exec "INSERT OR IGNORE INTO posts VALUES ( ?, ?);", [hash, text]
end

def store_comment(parent_hash, text)
	SQLite.exec "INSERT INTO comments (parent, content, date) VALUES ( ?, ?, ?);", [parent_hash, text, Time.now.epoch]
end

def get_comments(hash : String) : Array(String) | Nil
	return SQLite.query_all(%(SELECT * FROM comments WHERE parent='#{hash}' ORDER BY id), as: {Int32, String, String, Int32}).map{|t| t[2]}
end

get "/" do |env|
	render "src/views/landing.html.ecr", "src/views/layout.html.ecr"
end

post "/post" do |env|
	body =  env.params.body["post-body"]
	puts "Secret posted: " + body
	store_post body
	env.redirect "/"
end

post "/comment" do |env|
	parent = env.params.body["parent"]
	text = env.params.body["text"]
	puts "Comment posted on: " + parent
	store_comment(parent, text)
	env.redirect "/secret/#{parent}"
end

get "/secret/:hash" do |env|
	hash = env.params.url["hash"]
	q = SQLite.query_one?("SELECT * FROM posts WHERE id=\'#{hash}\' LIMIT 1;", as: {String, String})
	if q.nil?
		env.response.status_code = 404
	else
		link = q[0]
		body = q[1]
		comments = get_comments(q[0])
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
		comments = get_comments(q[0])
		render "src/views/post.html.ecr", "src/views/layout.html.ecr"
	end
end

get "/stats" do |env|
	comments_q = SQLite.query_all "SELECT * FROM comments;", as: Int64
	posts_q = SQLite.query_all "SELECT * FROM posts;", as: String

	comments_num = comments_q.size
	posts_num = posts_q.size
	render "src/views/stats.html.ecr", "src/views/layout.html.ecr"
end

Kemal.run
