class ConditionsController < ApplicationController
  # GET /conditions/new
  # GET /conditions/new.json
  def new
    @condition = Condition.new
    
    @day_type = 'from'
    @condition.from = Sleep.where(:user_id => @user.id).first.date.to_date
    @condition.experiment_id = params[:experiment_id]

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @condition }
    end
  end

  # GET /conditions/1/edit
  def edit
    @condition = Condition.find(params[:id])
    
    if @condition.to == nil
        @day_type = 'from'
    elsif @condition.from == nil
        @day_type = 'to'
    else
        @day_type = 'between'
    end
  end

  # POST /conditions
  # POST /conditions.json
  def create
    @condition = Condition.new(params[:condition])

    respond_to do |format|
      if @condition.save
        format.html { redirect_to experiment_url(:id => @condition.experiment_id) }
        format.json { render json: @condition, status: :created, location: @condition }
      else
        format.html { render action: "new" }
        format.json { render json: @condition.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /conditions/1
  # PUT /conditions/1.json
  def update
    @condition = Condition.find(params[:id])

    respond_to do |format|
      if @condition.update_attributes(params[:condition])
        format.html { redirect_to experiment_url(:id => @condition.experiment_id) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @condition.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /conditions/1
  # DELETE /conditions/1.json
  def destroy
    @condition = Condition.find(params[:id])
    @condition.destroy

    respond_to do |format|
      format.html { redirect_to experiment_url(:id => @condition.experiment_id)  }
      format.json { head :no_content }
    end
  end
end
