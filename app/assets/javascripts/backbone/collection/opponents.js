var app = app || {};

app.Opponents = Backbone.Collection.extend({
	model: app.Player,
	initialize: function(){
		this.url=$('#table').data('table_id')+'/players_info';
		_.bindAll(this, "retryFetch");
		this.retries = 0;
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
		if( (type == "rankings") || (type == "protagonist_cards" && this.getProtagonistModel() ) ){
			app.pubSub.trigger("allowedToAdvanceStatus", false);
			$("#announcements").addClass("loading");
		}
		if(typeof this.retries == 'undefined')
			this.retries = 0;
		var that = this;
		that.fetch({
			timeout: 2000 + this.retries*1000,
			error: function(xhr, textStatus, errorThrown){
				if(textStatus["statusText"] == "timeout"){
					that.retryFetch();
					that.retries += 1;
					if(this.retries > 4)
						bootbox.alert("Your connection to the server is very poor.  We recommend you try again some other time.");
				}
			},
			success: function(data){
				that.retries=0;
				var tooEarly = false;
				data.each(function(player){
					if(type == "rankings"){
						if(!player.attributes["rankings"]){
							tooEarly = true;
						}
					}
					else if(type == "protagonist_cards"){
						if(player.attributes["protagonist"] && !player.attributes["arrangement"]){
							tooEarly = true;
						}
					}
				});
				if(tooEarly){
					setTimeout(that.retryFetch, 1000, type);
				}
				else{
					app.pubSub.trigger("allowedToAdvanceStatus", true);
					$("#announcements").removeClass("loading");
				}
			}
		});
	}
});