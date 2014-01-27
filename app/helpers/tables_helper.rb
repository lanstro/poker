module TablesHelper

	def card_file_paths
		paths = Dir.glob("app/assets/images/cards/*.png")
		results = {}
		paths.each do |a|
			temp = File.basename(a, ".png")
			results[temp]=image_path "cards/"+temp+".png"
		end
		return results
	end
	
	def small_avatar_file_paths
		paths = Dir.glob("app/assets/images/avatars/*_small.png")
		results={}
		paths.each do |a|
			temp = File.basename(a, "_small.png")
			results[temp]=image_path "avatars/"+temp+"_small.png"
		end
		return results
	end
	
	def hand_ranking_icon_paths
		paths = Dir.glob("app/assets/images/other/ranking_buttons/*.png")
		results={}
		paths.each do |a|
			temp = File.basename(a, ".png")
			results[temp]=image_path "other/ranking_buttons/"+temp+".png"
		end
		return results
	end
end
