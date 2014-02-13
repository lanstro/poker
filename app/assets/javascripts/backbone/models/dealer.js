var app = app || {};

app.Dealer = Backbone.Model.extend ({
	initialize: function(){
		_.bindAll(this, "carefulFetch", "testTime");
		this.url=$("#table").data("table_id")+'/status';
		this.retries = 0;
		this.serverTimeOffset = 0;
		this.offsets=[];
		this.testTime();
		this.alreadyCarefulFetching=false;
	},
	
	carefulFetch: function(){
		var that = this;
		if(that.alreadyCarefulFetching)
			return;
		that.alreadyCarefulFetching=true;
		$.ajax({
			type: "GET",
			url: that.url,
			dataType: "json",
			contentType: 'application/json',
			timeout: 2000 + that.retries*1000,
			error: function(xhr, textStatus, errorThrown){
				that.alreadyCarefulFetching=false;
				if(textStatus == "timeout"){
					that.retries+=1
					if(that.retries + 1 > 4){
						bootbox.alert("We have failed repeatedly to communicate with the server.  We recommend you try again some other time.");
						return;
					}
					that.carefulFetch();
				}
			},
			success: function(data){
				that.alreadyCarefulFetching=false;
				that.retries=0;
				that.set("in_join_queue", data["in_join_queue"]);
				if(data["timings"]["next_status"] <= that.get("status")){
					console.log("table status ahead of server, wait for server to catch up");
					window.setTimeout(that.carefulFetch, 1000);
				}
				else if(data["status"] > that.get("status")){
					console.log("table behind server - let's ask driver if we're allowed to go to new status yet, and let syncDriver know when next timing is supposed to be");
					that.trigger("tryToAdvanceStatus", data["status"]);
					that.set("timings", data["timings"]);
				}
				else{
					that.set("timings", data["timings"]);
					console.log("status is synched with server, let's just readjust timings");
				}
			}
		});
	},

	testTime: function() {

		if(this.offsets.length >= 4){
			var minOffset=this.offsets[0];
			_.each(this.offsets, function(offset){
				if(Math.abs(offset) < Math.abs(minOffset))
					minOffset = offset;
			});
			this.serverTimeOffset = minOffset;
			this.offsets=[];
			this.trigger("change:timings", this);
			return;
		}
		else{
			var that = this;
			var start = Date.now() / 1000;
			$.getJSON('server_time', function(serverTime){
				var end = Date.now() / 1000;
				that.offsets.push((start + end)/2 - serverTime);
				setTimeout(that.testTime, 1000);
			});
		}
	},

});