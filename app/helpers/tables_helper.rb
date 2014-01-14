module TablesHelper

	def card_file_paths
		paths = Dir.glob("app/assets/images/cards/*.png")
		results = {}
		paths.each do |a|
			temp = File.basename(a, ".png")
			results[temp]=image_path "cards/"+temp+".png"
		end
		lg = Logger.new("log/kai_log")
		lg.info(results.inspect)
		return results
	end

end
