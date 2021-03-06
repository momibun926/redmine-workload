require_dependency 'user'

# Patches Redmine's Issues dynamically. Adds a relationship
# Issue +belongs_to+ to Deliverable
module Workload
  module UserPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      # Same as typing in the class
      base.class_eval do
        unloadable
      end

    end

    module ClassMethods
    end

    module InstanceMethods
      def issues(project_id)
        return Issue.where(
            "#{Issue.table_name}.project_id = ?
            AND #{Issue.table_name}.assigned_to_id = ?",
            project_id, self.id
        )
      end
      def workload_issues(project, from_date, to_date)
        return Issue.open().find(
           :all,
           :joins => [:assigned_to],
           :order => "#{User.table_name}.lastname ASC",
           :conditions => 
              ["#{Issue.table_name}.project_id = ?
              AND #{Issue.table_name}.start_date <= ?
              AND #{Issue.table_name}.due_date  >= ?
              AND #{Issue.table_name}.estimated_hours  != ?
              AND #{Issue.table_name}.assigned_to_id = ?", project, to_date, from_date, "", self.id]
          )

      end
      def workload(project, from_date, to_date)
        issues = self.workload_issues(project, from_date, to_date)
        schedule = {}

        # make issues into a :date=>:workload schedule
        for issue in issues
            # チケットの期間を1日毎に分割
            ary_issue_dates = (issue[:start_date]..issue[:due_date]).to_a
            ary_issue_dates_weekday = (issue[:start_date]..issue[:due_date]).to_a

            # 土日を除く
            ary_issue_dates.delete_if{|x| x.cwday == 6 || x.cwday == 7}  

            if ary_issue_dates.size != 0
                # PV:日割りした工数を案分してセット
                ary_issue_dates.each do |date|
                    if schedule[date].nil?
                        schedule[date] = 0.0
                    end
                    schedule[date] += issue.workload
                end   
            else
                # PV:日割りした工数を案分してセット
                ary_issue_dates_weekday.each do |date|
                    if schedule[date].nil?
                        schedule[date] = 0.0
                    end
                    schedule[date] += issue.workload
                end   
            end
         
        end

        # merge schedule in following days with same workload into blocks
        # a block is a hash containing :start_date, :due_date and :workload
        blocks = []
        schedule.each do |date, load|
            latest = blocks.last
            # merge block
            if latest and date == latest[:due_date]+1 and load == latest[:workload]
                blocks.last[:due_date] = date
            # or create new block
            else
                blocks << {:start_date => date, :due_date => date, :workload => load}
            end
        end

        return blocks
      end
    end
  end
end

# Add module to Issue
User.send(:include, Workload::UserPatch) unless User.included_modules.include? Workload::UserPatch
""" quick testing in console
p = Project.last
u = User.find(4)
u.workload(p)
"""