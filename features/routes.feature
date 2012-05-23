Feature: Routes
  As a user
  I want pages to have proper urls
  So that I can bookmark them

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a scrum master of the project

  Scenario: Backlogs page
     When I get the "rb/master_backlog/ecookbook" page
     Then application should route me to:
          | controller | rb_master_backlogs |
          | action     | show               |
          | project_id | ecookbook          |
      And the request should complete successfully

  Scenario: Server variables script
     When I get the "rb/server_variables.js" page using format "js"
     Then application should route me to:
          | controller | rb_all_projects  |
          | action     | server_variables |
      And the request should complete successfully

  Scenario: Task create page
     When I post the "rb/task" page with params:
          | project_id | ecookbook |
     Then application should route me to:
          | controller | rb_tasks  |
          | action     | create    |
      And the request should complete successfully

  Scenario: Task update page
     When I put the "rb/task/1" page with params:
          | project_id | ecookbook |
     Then application should route me to:
          | controller | rb_tasks  |
          | action     | update    |
          | id         | 1         |
      And the request should complete successfully

