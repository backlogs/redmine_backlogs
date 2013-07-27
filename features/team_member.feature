Feature: Team Member
  As a team member
  I want to manage update stories and tasks
  So that I can update everyone on the status of the project

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And I add the tracker Bug to the story trackers
      And I am a team member of the project
      And I have deleted all existing issues
      And I have defined the following logins:
        | login  |
        | myuser |
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     |
        | Sprint 003 | 2010-03-01        | 2010-03-31     |
        | Sprint 004 | 2010-03-01        | 2010-03-31     |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | tracker |
        | Story 1 | Sprint 001 | Story   |
        | Story 2 | Sprint 001 | Story   |
        | Story 3 | Sprint 001 | Story   |
        | Story 4 | Sprint 002 | Story   |
        | Bug 1   | Sprint 001 | Bug     |
      And I have defined the following tasks:
        | subject | story   | assigned_to |
        | Task 1  | Story 1 | myuser      |
        | Task 1B | Bug 1   |             |
      And I have defined the following impediments:
        | subject      | sprint     | blocks  |
        | Impediment 1 | Sprint 001 | Story 1 |
        | Impediment 2 | Sprint 001 | Story 2 |
         
  @javascript
  Scenario: Update a task with full javascript stack to check assigned user is not overwritten during update.
    Given I am viewing the taskboard for Sprint 001
     When I change the subject of task "Task 1" to "Whoa there, Sparky"
     Then the request should complete successfully
     Then the story named Story 1 should have 1 task named Whoa there, Sparky
      And the 1st task for Story 1 is assigned to myuser

  Scenario: Create a task for a story
    Given I am viewing the taskboard for Sprint 001
      And I want to create a task for Story 1
      And I set the subject of the task to A Whole New Task
      And I set the assigned_to of the task to myuser
     When I create the task
     Then the 2nd task for Story 1 should be A Whole New Task
     Then the 2nd task for Story 1 is assigned to myuser

  Scenario: Create a task for a bug
    Given I am viewing the taskboard for Sprint 001
      And I want to create a task for Bug 1
      And I set the subject of the task to A Whole New Bug Task
     When I create the task
     Then the 2nd task for Bug 1 should be A Whole New Bug Task

  Scenario: Update a task for a story
    Given I am viewing the taskboard for Sprint 001
      And I want to edit the task named Task 1
      And I set the subject of the task to Whoa there, Sparky
     When I update the task
     Then the story named Story 1 should have 1 task named Whoa there, Sparky

  Scenario: Update a task for a bug
    Given I am viewing the taskboard for Sprint 001
      And I want to edit the task named Task 1B
      And I set the subject of the task to Whoa! - Neo
     When I update the task
     Then the story named Bug 1 should have 1 task named Whoa! - Neo

  Scenario: View a taskboard
    Given I am viewing the taskboard for Sprint 001
     Then I should see the taskboard

  Scenario: View the burndown chart
    Given I am viewing the burndown for Sprint 002
     Then I should see the burndown chart

  Scenario: View issues tab with custom backlog columns
    Given I view issues tab with backlog columns
     Then I should see custom backlog columns on the Issues page

  Scenario: View sprint stories in the issues tab
    Given I am viewing the master backlog
     When I view the stories of Sprint 001 in the issues tab
     Then I should see the Issues page

  Scenario: View the project stories in the issues tab
    Given I am viewing the master backlog
     When I view the stories in the issues tab
     Then I should see the Issues page

  Scenario: Fetch the updated tasks
    Given I am viewing the taskboard for Sprint 001
     When the browser fetches tasks updated since 1 week ago
     Then the server should return 2 updated task
     #FIXME tests on sharing

  Scenario: Fetch the updated impediments
    Given I am viewing the taskboard for Sprint 001
     When the browser fetches impediments updated since 1 week ago
     Then the server should return 2 updated impediments
     #FIXME tests on sharing

  Scenario: Fetch zero updated impediments 
    Given I am viewing the taskboard for Sprint 001
     When the browser fetches impediments updated since 1 week from now
     Then the server should return 0 updated impediments
      
  Scenario: Copy estimate to remaining
    Given I am viewing the taskboard for Sprint 001
      And I want to create a task for Story 1
      And I set the subject of the task to A Whole New Task
      And I set the estimated_hours of the task to 3
     When I create the task
     Then the request should complete successfully
      And task A Whole New Task should have remaining_hours set to 3

  Scenario: Copy remaining to estimate
    Given I am viewing the taskboard for Sprint 001
      And I want to create a task for Story 1
      And I set the subject of the task to A Whole New Task
      And I set the estimated_hours of the task to 3
     When I create the task
     Then task A Whole New Task should have estimated_hours set to 3

  Scenario: Set both estimate and remaining
    Given I am viewing the taskboard for Sprint 001
      And I want to create a task for Story 1
      And I set the subject of the task to A Whole New Task
      And I set the estimated_hours of the task to 8
     When I create the task
      And I want to create a task for Story 1
      And I set the subject of the task to A Second New Task
      And I set the estimated_hours of the task to 2
     When I create the task
     Then task A Whole New Task should have estimated_hours set to 8
      And story Story 1 should have estimated_hours set to 10
      And story Story 1 should have estimated_hours set to 10

#mikotos original implementation: Story autocloses (Setting default off)
  Scenario: Story closes when all Tasks are closed
    Given I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                  0 |
        | Assigned    |         0 |          0 |                 10 |
        | In Progress |         0 |          0 |                 20 |
        | Resolved    |         0 |          0 |                 90 |
        | Feedback    |         0 |          0 |                 50 |
        | Closed      |         1 |          0 |                100 |
        | Accepted    |         1 |          0 |                100 |
        | Rejected    |         1 |          0 |                100 |
      And I have defined the following tasks:
        | subject      | story            | estimate | status |
        | A.1          | Story 2          | 10       | New    |
        | A.2          | Story 2          | 10       | New    |
        | B.1          | Story 3          | 10       | New    |
      And I am viewing the taskboard for Sprint 001
    #negative test
     Then story Story 3 should have the status New
     When I update the status of task B.1 to In Progress
     Then story Story 3 should have the status New
     When I update the status of task B.1 to Closed
     Then story Story 3 should have the status New
    #positive test
    Given Story closes when all Tasks are closed
     Then story Story 2 should have the status New
     When I update the status of task A.1 to In Progress
     Then story Story 2 should have the status New
     When I update the status of task A.2 to In Progress
     Then story Story 2 should have the status New
     When I update the status of task A.1 to Closed
     Then story Story 2 should have the status New
     When I update the status of task A.2 to Closed
     Then story Story 2 should have the status Closed

# now the loosely part

#    Prerequisite ** Set default_done_ratio for all statuses involved (user action)
# Beware: to get the right behavior, one has to fiddle with story workflow and good ratios.
# In this case, not all states below are allowed for stories (e.g. not In Progress)    
  Scenario: Story loosely follows Task states while done_ratio is determined by story_state default ratio
    Given I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                  0 |
        | Assigned    |         0 |          0 |                 10 |
        | In Progress |         0 |          0 |                 20 |
        | Resolved    |         0 |          0 |                 90 |
        | Feedback    |         0 |          0 |                 50 |
        | Closed      |         1 |          0 |                100 |
        | Accepted    |         1 |          0 |                100 |
        | Rejected    |         1 |          0 |                100 |
      And I have defined the following tasks:
        | subject      | story            | estimate | status |
        | A.1          | Story 2          | 10       | New    |
        | A.2          | Story 2          | 10       | New    |
        | B.1          | Story 3          | 10       | New    |
      And Story states loosely follow Task states
      And I am viewing the taskboard for Sprint 001
     Then story Story 2 should have the status New
     When I update the status of task A.1 to Assigned
     Then story Story 2 should have the status New
     When I update the status of task A.2 to Assigned
     Then story Story 2 should have the status Assigned

     When I update the status of task A.1 to Resolved
     When I update the status of task A.2 to Resolved
     Then story Story 2 should have the status Feedback

     When I update the status of task A.1 to Closed
     Then story Story 2 should have the status Feedback
     When I update the status of task A.2 to Closed
     Then story Story 2 should have the status Feedback

# Beware: to get the right behavior, one has to fiddle with story workflow and good ratios.
# In this case, not all states below are allowed for stories (e.g. not In Progress)    
  Scenario: Story loosely follows Task states when issue done_ratio is maintained by issue_field
    Given I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                  0 |
        | Assigned    |         0 |          0 |                 10 |
        | In Progress |         0 |          0 |                 20 |
        | Resolved    |         0 |          0 |                 90 |
        | Feedback    |         0 |          0 |                 50 |
        | Closed      |         1 |          0 |                100 |
        | Accepted    |         1 |          0 |                100 |
        | Rejected    |         1 |          0 |                100 |
      And I have defined the following tasks:
        | subject      | story            | estimate | status |
        | A.1          | Story 2          | 10       | New    |
        | A.2          | Story 2          | 10       | New    |
        | B.1          | Story 3          | 10       | New    |
      And Story states loosely follow Task states
      And Issue done_ratio is determined by the issue field
      And I am viewing the taskboard for Sprint 001
     Then story Story 2 should have the status New
     When I update the status of task A.1 to Assigned
     Then story Story 2 should have the status New
      And the done ratio for story Story 2 should be 0

     When I update the status of task A.2 to Assigned
     Then story Story 2 should have the status Assigned
      And the done ratio for story Story 2 should be 0

     When I update the status of task A.1 to Resolved
     When I update the status of task A.2 to Resolved
     Then story Story 2 should have the status Feedback
      And the done ratio for story Story 2 should be 0

     When I update the status of task A.1 to Closed
     Then story Story 2 should have the status Feedback
     When I update the status of task A.2 to Closed
     Then story Story 2 should have the status Feedback
      And the done ratio for story Story 2 should be 100

  Scenario: Story loosely follows Task states while done_ratio is determined by story_state default ratio
    Given I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                  0 |
        | Assigned    |         0 |          0 |                    |
        | In Progress |         0 |          0 |                 20 |
        | Resolved    |         0 |          0 |                 90 |
        | Feedback    |         0 |          0 |                 50 |
        | Closed      |         1 |          0 |                100 |
        | Accepted    |         1 |          0 |                100 |
        | Rejected    |         1 |          0 |                100 |
      And I have defined the following tasks:
        | subject      | story            | estimate | status |
        | A.1          | Story 2          | 10       | New    |
        | A.2          | Story 2          | 10       | New    |
        | B.1          | Story 3          | 10       | New    |
      And Story states loosely follow Task states
      And I am viewing the taskboard for Sprint 001
     Then story Story 2 should have the status New
     When I update the status of task A.1 to Assigned
     When I update the status of task A.2 to Assigned
     Then story Story 2 should have the status Assigned
     When I update the status of task A.1 to Closed
     When I update the status of task A.2 to Closed
     Then story Story 2 should have the status Feedback
