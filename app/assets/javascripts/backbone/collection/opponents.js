var app = app || {};

app.Opponents = Backbone.Collection.extend({
	model: app.Player,
	initialize: function(){
		this.url=$('#table').data('table_id')+'/players_info';
		_.bindAll(this, "retryFetch");
		this.retries = 0;
		this.alreadyRetryFetching=false;
	},
	
	getProtagonistModel: function(){
		return this.where({"protagonist" : true })[0];
	},
	
	hasRankings: function(){
		var result = true;
		this.each(function(player){
			if(!player.get("rankings"))
				result = false
		});
		return result;
	},
	
	protagonistHasHand: function(){
		var model = this.getProtagonistModel();
		if(!model){
			return false;
		}
		if(model.get("arrangement"))
			return true;
		return false;
	},
	
	tooManyFolders: function(){
		var count = 0;
		this.each(function(player){
			if(!player.get("folded"))
				count += 1;
		});
		return count <= 1;
	},
	
	retryFetch: function(type){
	
		if(this.alreadyRetryFetching)
			return;
	
		if( (type == "rankings") || (type == "protagonist_cards" && this.getProtagonistModel() ) ){
			
			// these two types of fetches are important - lock down status and show loading icon while they happening
			app.pubSub.trigger("allowedToAdvanceStatus", false);
			$("#announcements").addClass("loading");
		}

		var that = this;
		that.alreadyRetryFetching=true;
		
		that.fetch({
			timeout: 2000 + this.retries*1000,
			error: function(xhr, textStatus, errorThrown){
				that.alreadyRetryFetching=false;
				if(textStatus["statusText"] == "timeout"){
					that.retries += 1;
					if(that.retries > 4){
						bootbox.alert("Your connection to the server is very poor.  We recommend you try again some other time.");
						return;
					}
					that.retryFetch();
				}
			},
			success: function(data){
				that.alreadyRetryFetching=false;
				that.retries=0;
				var tooEarly = false;
				data.each(function(player){
					if(type == "rankings"){
						if(!player.attributes["rankings"]){
							console.log("tried to get showdown rankings, but too early");
							tooEarly = true;
						}
					}
					else if(type == "protagonist_cards"){
						if(player.attributes["protagonist"] && !player.attributes["arrangement"]){
							tooEarly = true;
							console.log("tried to get protagonist cards, but too early");
						}
					}
				});
				if(tooEarly){
					setTimeout(that.retryFetch, 1000, type);
				}
				else{
					console.log("opponentsView fetch success");
					app.pubSub.trigger("allowedToAdvanceStatus", true);
					$("#announcements").removeClass("loading");
				}
			}
		});
	}
});