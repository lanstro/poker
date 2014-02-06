var app = app || {};

app.Dealer = Backbone.Model.extend ({
	initialize: function(){
		_.bindAll(this, "carefulFetch");
		this.url=$("#table").data("table_id")+'/status';
		this.set("retries", 0);
	},
	
	carefulFetch: function(){
		var that = this;
		var retries = that.get("retries");
		$.ajax({
			type: "GET",
			url: that.url,
			dataType: "json",
			contentType: 'application/json',
			timeout: 2000 + retries*1000,
			error: function(xhr, textStatus, errorThrown){
				if(textStatus == "timeout"){
					that.carefulFetch();
					that.set("retries", retries+1);
					if(retries + 1 > 4)
						bootbox.alert("Your connection to the server is very poor.  We recommend you try again some other time.");
				}
			},
			success: function(data){
				that.set("retries", 0);
				// if the server's next_status is less than or equal to client's current status, it means
				// javascript is ahead - keep redoing this ajax until it's no longer the case
				that.set("in_join_queue", data["in_join_queue"]);
				if(data["timings"]["next_status"] <= that.get("status"))
					window.setTimeout(that.carefulFetch, 1000);
				else if(data["status"] > that.get("status"))
					that.set(data);
				else
					that.set("timings", data["timings"]);
			}
		});
	}
});