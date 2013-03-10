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
      And I have defined the following releases:
        | name    | project    | release_start_date | release_end_date |
        | Rel 1   | ecookbook  | 2011-01-02         | 2011-01-31       |
      And I have defined the following stories in the product backlog:
        | subject | release | points |
        | Story 1 | Rel 1   | 2 |
        | Story 2 | Rel 1   | 7 |
        | Story 5 |         | 40 |

   Scenario: View initial release burndown before release start date
    Given I view the release page
     Then release "Rel 1" should have 0 sprints
      And show me the burndown data for release "Rel 1"
      And the release burndown for release "Rel 1" should be:
        | sprint| backlog_points | closed_points | added_points |
        | start | 9              | 0             | 0            |

   Scenario: Simple release burndown
    Given I view the release page
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story A | Sprint 001 | Rel 1   | 2 |
        | Story B | Sprint 002 | Rel 1   | 3 |
    Given I have made the following story mutations:
        | day | story   | status      |
        | 1   | Story A | In Progress |
        | 2   | Story A | Accepted    |
        | 3   | Story B | Feedback    |
        | 4   | Story B | Rejected    |
      And the current time is 2011-01-31 23:00:00
     Then release "Rel 1" should have 2 sprints
      And show me the burndown data for release "Rel 1"
      #points at the end of the corresponding sprint
      And the release burndown for release "Rel 1" should be:
        | sprint| backlog_points | closed_points | added_points |
        | start | 14        | 0         | 0     |
        | 1     | 12        | 2         | 0     |
        | 2     |  9        | 0         | 0     |

   Scenario: See planned/trend end date at different time in the release.
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
# Reason: In the middle of a sprint - planned/trend estimate should start from last sprint.
      And Rel 1 has planned timespan of 72 days starting from 2011-01-08
# Reason: 2 points/6 days = 0.33 points per day => 36 days to complete 12 points
      And Rel 1 has trend estimate end date at 2011-02-13

      And the current time is 2011-01-16 23:00:00
     Then show me the burndown data for release "Rel 1"
# Reason: No current sprint - planned estimate should start from today.
      And Rel 1 has planned timespan of 72 days starting from 2011-01-16
# Reason: 2 points/14 days = 0.143 points/day => 84 days to complete 12 points
      And Rel 1 has trend estimate end date at 2011-04-10

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
# Similar to previous scenario. Added story is not yet in calculation window
      And Rel 1 has trend estimate end date at 2011-02-13
      And the current time is 2011-01-16 23:00:00
     Then show me the burndown data for release "Rel 1"
# Added story in calculation window. By linear extrapolation of
# trend added and closed it takes 182 days to complete release
      And Rel 1 has trend estimate end date at 2011-07-17

   Scenario: Story closed after sprint end date should appear closed in the original sprint
    Given I view the release page
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story A | Sprint 001 | Rel 1   | 2      |
        | Story B | Sprint 002 | Rel 1   | 3      |
      And the current time is 2011-01-12 23:00:00
      And I accept story Story A
     Then show me the burndown data for release "Rel 1"
      And the release burndown for release "Rel 1" should be:
        | sprint| backlog_points | closed_points | added_points | offset_points |
        | start | 14             | 0         | 0     | 0  |
        | 1     | 12             | 2         | 0     | 0  |
        | 2     | 12             | 0         | 0     | 0  |
      And the current time is 2011-01-16 23:00:00
     Then show me the burndown data for release "Rel 1"
      And the release burndown for release "Rel 1" should be:
        | sprint| backlog_points | closed_points | added_points | offset_points |
        | start | 14             | 0         | 0     | 0  |
        | 1     | 12             | 2         | 0     | 0  |
        | 2     | 12             | 0         | 0     | 0  |
        | 3     | 12             | 0         | 0     | 0  |



#   Scenario: Add complexity by re-estimating a story
#    Given the current time is 2011-01-15 08:00:00
#     When I update story "Story 3" to 13 story points
#
#   Scenario: Add a story to running release
#    Given the current time is 2011-01-15 08:00:00
#     When I add a story to release "Rel 1"
#
#   Scenario: Split a story
#    Given the current time is 2011-01-31 08:00:00
#     When I copy story "Story A" into "Story A.cont"
#     When I reject story "Story A"
#     When update story "Story A.cont" to 5 story points
#
#   Scenario: reject and re-open a story
