Feature: Release burndown
  As a product owner
  I want to analyze the progress of my releases
  So that i can get a feeling for the projects progress

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a product owner of the project
      And I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                    |
        | In Progress |         0 |          0 |                    |
        | Feedback    |         0 |          0 |                    |
        | Accepted    |         1 |          0 |                    |
        | Rejected    |         1 |          0 |                  1 |
      And the current time is 2011-01-01 08:00:00
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2011-01-02        | 2011-01-08     |
        | Sprint 002 | 2011-01-09        | 2011-01-15     |
        | Sprint X   |                   |                |
      And I have defined the following releases:
        | name    | project    | release_start_date | release_end_date |
        | Rel 1   | ecookbook  | 2011-01-02         | 2011-01-31       |
      And I have defined the following stories in the product backlog:
        | subject | release | points |
        | Story 1 | Rel 1   | 2 |
        | Story 2 | Rel 1   | 7 |
        | Story 5 |         | 40 |

   Scenario: See planned end date at different time in the release.
    Given I view the release page
      And I have set planned velocity to 5 points per month for Rel 1
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story A | Sprint 001 | Rel 1	 | 2 |
        | Story B | Sprint 002 | Rel 1   | 3 |
      And I have made the following story mutations:
        | day | story   | status   |
        | 1   | Story A | Accepted |
      And the current time is 2011-01-12 23:00:00
     Then show me the burndown data for release "Rel 1"
      And Rel 1 has planned timespan of 72 days starting from 2011-01-08
      And the current time is 2011-01-16 23:00:00
# Reason: No current sprint - planned estimate should start from today.
      And Rel 1 has planned timespan of 72 days starting from 2011-01-16


   Scenario: See trend end date at different time in the release.
    Given I view the release page
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story A | Sprint 001 | Rel 1	 | 2 |
        | Story B | Sprint 002 | Rel 1   | 3 |
      And I have made the following story mutations:
        | day | story   | status   |
        | 1   | Story A | Accepted |
      And the current time is 2011-01-12 23:00:00
     Then show me the burndown data for release "Rel 1"
      And Rel 1 has trend closed based on dates "2011-01-02,2011-01-08"
      And Rel 1 has trend closed with slope of 0.333 points per day intercepting at 0.0 points
      And Rel 1 has trend scope based on dates "2011-01-08,2011-01-15"
      And Rel 1 has trend scope with slope of 0 points per day intercepting at 14 points
# Reason: Trend closed uses data available from the past sprints
#         Trend scope is allowed to use latest available changes to project scope
      And Rel 1 has trend estimate end date at 2011-02-13
# Reason: Slope of 0.333 points per day => 36 days to complete 12 remaining points in backlog

      And the current time is 2011-01-16 23:00:00
     Then show me the burndown data for release "Rel 1"
      And Rel 1 has trend closed based on dates "2011-01-02,2011-01-08,2011-01-15,2011-01-16"
      And Rel 1 has trend closed with slope of 0.128 points per day intercepting at 0.442 points
# Slope is least mean square estimate from closed points [0,2,2,2].
      And Rel 1 has trend scope based on dates "2011-01-02,2011-01-08,2011-01-15,2011-01-16"
      And Rel 1 has trend scope with slope of 0 points per day intercepting at 14 points
# Reason: No current sprint - today is taking into the estimates also.
      And Rel 1 has trend estimate end date at 2011-04-17  # Equation: 14 = 0.128155*x + 0.442 => x= 105 days


   Scenario: See impact of added stories to trend estimate end date
    Given I view the release page
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story A | Sprint 001 | Rel 1   | 2      |
        | Story B | Sprint 002 | Rel 1   | 3      |
      And I have made the following story mutations:
        | day | story   | status   |
        | 1   | Story A | Accepted |
      And the current time is 2011-01-12 23:00:00
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story C | Sprint 002 | Rel 1   | 1      |
     Then show me the burndown data for release "Rel 1"
# Added story already in calculation window
      And Rel 1 has trend closed based on dates "2011-01-02,2011-01-08"
      And Rel 1 has trend closed with slope of 0.333 points per day intercepting at 0 points
      And Rel 1 has trend scope based on dates "2011-01-08,2011-01-15"
      And Rel 1 has trend scope with slope of 0.143 points per day intercepting at 14 points
      And Rel 1 has trend estimate end date at 2011-03-12
# Verified by calculating crossing date of trend closed and trend scope in spreadsheet
      And the current time is 2011-01-16 23:00:00
     Then show me the burndown data for release "Rel 1" 
      And Rel 1 has trend closed based on dates "2011-01-02,2011-01-08,2011-01-15,2011-01-16"
      And Rel 1 has trend closed with slope of 0.128 points per day intercepting at 0.442 points
      And Rel 1 has trend scope based on dates "2011-01-02,2011-01-08,2011-01-15,2011-01-16"
# Next one verified by linear regression in spreadsheet.
      And Rel 1 has trend scope with slope of 0.082 points per day intercepting at 13.83 points
# By linear regression of trend scope and trend closed crossing date is found in spreadsheet.
      And Rel 1 has trend estimate end date at 2011-10-16

