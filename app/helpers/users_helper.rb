module UsersHelper
	def avatar_for(user, size)
		if size=="small"
			image_tag("avatars/"+user.avatar.to_s+"_small.png", alt: user.name+"'s avatar", class: "user_avatar")
		else
			image_tag("avatars/"+user.avatar.to_s+".png", alt: user.name+"'s avatar", class: "user_avatar")
		end
	end
end
