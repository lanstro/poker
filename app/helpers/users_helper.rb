module UsersHelper
	def avatar_for(user)
		image_tag("avatars/"+user.avatar.to_s+".png", alt: user.name+"'s avatar", class: "user_avatar")
	end
end
