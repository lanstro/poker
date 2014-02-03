var app = app || {};

app.UtilityButtonsView = Backbone.View.extend({
	el: '#utility_buttons',
	initialize: function(){
		
		this.model = app.statusModel;
		
		_.bindAll(this, 'join', 'renderJoin', 'renderLeave', 'statusChanged', 'render', 'leave');
		
		this.joinButtonTemplate = $("#join_button_template").html();
		this.leaveButtonTemplate=$("#leave_button_template").html();
		this.sitoutButtonTemplate=$("#sitout_button_template").html();
		this.foldButtonTemplate=$("#fold_button_template").html();
		this.readyButtonTemplate=$("#ready_button_template").html();
		
		this.$joinButton = this.$("#join_button");
		this.$leaveButton = this.$("#leave_button");
		this.$sitoutButton = this.$("#sitout_button");
		this.$foldButton = this.$("#fold_button");
		this.$readyButton = this.$("#ready_button");
		
		this.listenToOnce(this.model, "sync", this.render);

		this.listenToOnce(app.playerInfoCollection, "sync", this.firstTime);
		
		this.listenTo(this.model, "change:status", this.statusChanged);
		this.listenTo(this.model, "change:in_join_queue", this.renderJoin);
		this.listenTo(this.model, "change:in_join_queue", this.renderLeave);

		// need to handle when table forces player to be sitting out
	},
	
	firstTime: function(){
		var protagonist = app.protagonistModel();
		if(!protagonist){
			console.log("utility buttons returned from firstTime because no protagonist.");
			return;
		}
		this.model2 = protagonist;
		this.listenTo(this.model2, "change:in_current_hand", this.render);
		this.listenTo(this.model2, "change:in_leave_queue", this.renderJoin);
		this.listenTo(this.model2, "change:in_leave_queue", this.renderLeave);
		this.listenTo(this.model2, "change:sitting_out", this.renderSitout);
		this.listenTo(this.model2, "change:folded", this.renderFold);
		this.listenTo(this.model2, "change:ready_for_showdown", this.renderReady);
		this.render();
	},
	
	events: {
		'click #join_button': "join",
		'click #leave_button': "leave",
		'click #sitout_button': "sitout",
		'click #fold_button': "fold",
		'click #ready_button': "ready"
	},
	
	render: function(){
		this.renderJoin();
		this.renderLeave();
		this.renderSitout();
		this.renderFold();
		this.renderReady();
		return this;
	},
	
	renderJoin: function(){
		this.$joinButton.empty();
		if(!this.model2 && !this.model.get("in_join_queue")){
			this.$joinButton.html(this.joinButtonTemplate);
			return this;
		}
		return this;
	},
	
	renderLeave: function(){
		this.$leaveButton.empty();
		if(this.model2){
			this.$leaveButton.html(this.leaveButtonTemplate);
			if(this.model2.get("in_leave_queue")){
				this.$leaveButton.children().val("Cancel rage quit");
			}
			return this;
		}
		else{
			if(this.model.get("in_join_queue")){
				this.$leaveButton.html(this.leaveButtonTemplate);
				this.$leaveButton.children().val("Cancel buy in");
				return this;
			}
			else{
				return this;
			}
		}
	},
	
	renderSitout: function(){
		this.$sitoutButton.empty();
		if(!this.model2){
			return this;
		}
		this.$sitoutButton.html(this.sitoutButtonTemplate);
		if(this.model2.get("sitting_out")){
			this.$sitoutButton.children().val("Deal me in!");
		}
	},
	
	renderFold: function(){
		this.$foldButton.empty();
		if(!this.model2){
			return this;
		}
		var status = app.statusModel.get("status");
		if( status < DEALING || status >= SHOWDOWN_NOTIFICATION){
			return this;
		}
		if(this.model2.get("folded")){
			return this;
		}
		this.$foldButton.html(this.foldButtonTemplate);
		return this;
	},
	
	renderReady: function(){
		this.$readyButton.empty();
		if(!this.model2){
			return this;
		}
		var status = app.statusModel.get("status");
		if( status < DEALING || status >= SHOWDOWN_NOTIFICATION){
			return this;
		}
		if(this.model2.get("folded")){
			return this;
		}
		this.$readyButton.html(this.readyButtonTemplate);
		return this;
	},
	
	statusChanged: function(data){
		if(data.get("status") >= DEALING && data.get("status") <= SHOWDOWN_NOTIFICATION){
			this.renderReady();
			this.renderFold();
		}
	},
	
	join: function(){
		var that = this;
		$.getJSON( $('#table').data('table_id')+'/join_table_details', function(data){
			if(!data){
				bootbox.alert("Please login first.");
				return;
			}
			if(data.balance < data.min_table_balance){
				bootbox.alert("You do not have the balance to join this table.  You have $"+data.balance+" and you need at least "+data.min_table_balance+".");
				return;
			}
			bootbox.prompt("How much would you like to buy in for?\nMinimum buy-in: $"+data.min_table_balance+"\nAvailable balance: $"+data.balance+"\nBalance on other tables: $"+data.table_balance,
				function(result){
					if(!result){
						return;
					}
					result = parseInt(result);
					if(!result){
						bootbox.alert("Please enter a positive number.");
						return;
					}
					else if(result < data.min_table_balance){
						bootbox.alert("That is less than the minimum buy-in for this table.");
						return;
					}
					else if(result > data.balance){
						bootbox.alert("You do not have that amount of money available.");
						return;
					}
					$.ajax({
						type: "POST",
						url: $('#table').data('table_id')+'/join',
						data: {amount: result},
					  dataType: "text/json",
						complete: function(response){
							response = $.parseJSON(response.responseText);
							bootbox.alert(response.response);
							that.model.set("in_join_queue", response.in_join_queue);
							if(that.model2)
								that.model2.set("in_leave_queue", false);
						}
					});
				}
			);
		});
	},
	
	leave: function(){
		var that = this;
		$.getJSON( $('#table').data('table_id')+'/leave', function(response){
			bootbox.alert(response.response);
			that.model2.set("in_leave_queue", response.in_leave_queue);
			that.model.set("in_join_queue", false);
		});
	},
	
	sitout: function(){
		var that = this;
		$.getJSON( $('#table').data('table_id')+'/sitout', function(response){
			bootbox.alert(response.response);
			that.model2.set("sitting_out", response.sitting_out);
		});
	},
	
	fold: function(){
		var that = this;
		that.model.set("folded", true);
		$.getJSON( $('#table').data('table_id')+'/fold', function(response){
			bootbox.alert(response.response);
			
			that.model2.set("ready_for_showdown", response.ready_for_showdown);
			// clear protagonist cards too
		});
	},
	
	ready: function(){
		var that = this;
		$.getJSON( $('#table').data('table_id')+'/ready', function(response){
			bootbox.alert(response.response);
			that.model2.set("folded", response.folded);
			that.model2.set("ready_for_showdown", response.ready_for_showdown);
		});
	}
});

