class WorkloadController < ApplicationController
  unloadable
  menu_item :workload


  helper :issues
  helper :projects
  helper :queries
  include QueriesHelper
  include ApplicationHelper

  helper_method :hours_to_class


  def api_request?
    return User.current.registered?
  end

  def index

    day = Date.today
    @from_date = Date::new(day.year,day.month, 1)
    end_date = @from_date  >> 1
    @to_date = end_date - 1

    retrieve_query

    @project = Project.find(params[:project_id])
    @issues = Issue.workload_estimable(@project, @from_date, @to_date).group_by(&:assigned_to)
    puts @issues
  end

  def hours_to_class(hours)
    hours = hours.to_i
    return 1 if hours < 1
    return hours if hours <= 8
    return 12 if hours <= 12
    return 100
  end
end
