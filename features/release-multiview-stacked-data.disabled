Feature: Test internal calculation of release multiview data

  Scenario: Add initial series to stacked data
    Given I initialize RbStackedData with closed date 2013-12-01
      And I add the following series "A":
        | days       | total_points | closed_points |
        | 2013-08-01 | 100          | 0             |
        | 2013-09-01 | 100          | 15            |
        | 2013-10-01 | 100          | 30            |
        | 2013-11-01 | 110          | 45            |
        | 2013-12-01 | 110          | 60            |
     And I finish RbStackedData
     Then series 0 should be:
        | days       | total_points |
        | 2013-08-01 | 100          |
        | 2013-09-01 | 100          |
        | 2013-10-01 | 100          |
        | 2013-11-01 | 110          |
        | 2013-12-01 | 110          |
      And closed series should be:
        | days       | closed_points |
        | 2013-08-01 | 0             |
        | 2013-09-01 | 15            |
        | 2013-10-01 | 30            |
        | 2013-11-01 | 45            |
        | 2013-12-01 | 60            |

  Scenario: Add two series to stacked data
    Given I initialize RbStackedData with closed date 2015-03-01
      And I add the following series "A":
        | days       | total_points | closed_points |
        | 2013-08-01 | 100          | 0             |
        | 2013-09-01 | 100          | 15            |
        | 2013-10-01 | 100          | 30            |
        | 2013-11-01 | 110          | 45            |
        | 2013-12-01 | 110          | 60            |
        | 2014-01-01 | 120          | 65            |
        | 2014-02-01 | 120          | 70            |
        | 2014-03-01 | 120          | 80            |
        | 2014-04-01 | 120          | 90            |
        | 2014-05-01 | 120          | 100           |
        | 2014-06-01 | 120          | 110           |
        | 2014-07-01 | 120          | 120           |
     And I add the following series "B":
        | days       | total_points | closed_points |
        | 2014-05-01 | 150          | 0             |
        | 2014-06-01 | 150          | 5             |
        | 2014-07-01 | 140          | 10            |
        | 2014-08-01 | 140          | 30            |
        | 2014-09-01 | 140          | 50            |
        | 2014-10-01 | 140          | 70            |
        | 2014-11-01 | 140          | 90            |
        | 2014-12-01 | 140          | 110           |
        | 2015-01-01 | 140          | 115           |
        | 2015-02-01 | 140          | 120           |
        | 2015-03-01 | 140          | 125           |
     And I finish RbStackedData
     Then series 0 should be:
        | days       | total_points |
        | 2013-08-01 | 100          |
        | 2013-09-01 | 100          |
        | 2013-10-01 | 100          |
        | 2013-11-01 | 110          |
        | 2013-12-01 | 110          |
        | 2014-01-01 | 120          |
        | 2014-02-01 | 120          |
        | 2014-03-01 | 120          |
        | 2014-04-01 | 120          |
        | 2014-05-01 | 120          |
        | 2014-06-01 | 120          |
        | 2014-07-01 | 120          |
      And series 1 should be:
        | days       | total_points |
        | 2014-05-01 | 270          |
        | 2014-06-01 | 270          |
        | 2014-07-01 | 260          |
        | 2014-08-01 | 260          |
        | 2014-09-01 | 260          |
        | 2014-10-01 | 260          |
        | 2014-11-01 | 260          |
        | 2014-12-01 | 260          |
        | 2015-01-01 | 260          |
        | 2015-02-01 | 260          |
        | 2015-03-01 | 260          |
      And closed series should be:
        | days       | closed_points |
        | 2013-08-01 | 0             |
        | 2013-09-01 | 15            |
        | 2013-10-01 | 30            |
        | 2013-11-01 | 45            |
        | 2013-12-01 | 60            |
        | 2014-01-01 | 65            |
        | 2014-02-01 | 70            |
        | 2014-03-01 | 80            |
        | 2014-04-01 | 90            |
        | 2014-05-01 | 100           |
        | 2014-06-01 | 115           |
        | 2014-07-01 | 130           |
        | 2014-08-01 | 150           |
        | 2014-09-01 | 170           |
        | 2014-10-01 | 190           |
        | 2014-11-01 | 210           |
        | 2014-12-01 | 230           |
        | 2015-01-01 | 235           |
        | 2015-02-01 | 240           |
        | 2015-03-01 | 245           |


  Scenario: Add two series without directly overlapping days
    Given I initialize RbStackedData with closed date 2015-03-01
      And I add the following series "A":
        | days       | total_points | closed_points |
        |2013-08-01  | 100          | 0             |
        |2013-09-01  | 100          | 15            |
        |2013-10-01  | 100          | 30            |
        |2013-11-01  | 110          | 45            |
        |2013-12-01  | 110          | 60            |
        |2014-01-01  | 110          | 65            |
        |2014-02-01  | 110          | 70            |
     And I add the following series "B":
        | days       | total_points | closed_points |
        | 2013-12-15 | 150          | 0             |
        | 2014-01-15 | 150          | 5             |
        | 2014-02-15 | 140          | 10            |
        | 2014-03-15 | 140          | 30            |
        | 2014-04-15 | 140          | 50            |
        | 2014-05-15 | 140          | 70            |
        | 2014-06-15 | 140          | 90            |
     And I finish RbStackedData
     Then series 0 should be:
        | days       | total_points |
        |2013-08-01  | 100          |
        |2013-09-01  | 100          |
        |2013-10-01  | 100          |
        |2013-11-01  | 110          |
        |2013-12-01  | 110          |
        |2013-12-15  | 110          |
        |2014-01-01  | 110          |
        |2014-01-15  | 110          |
        |2014-02-01  | 110          |
      And series 1 should be:
        | days       | total_points |
        | 2013-12-15 | 260          |
        | 2014-01-01 | 260          |
        | 2014-01-15 | 260          |
        | 2014-02-01 | 260          |
        | 2014-02-15 | 250          |
        | 2014-03-15 | 250          |
        | 2014-04-15 | 250          |
        | 2014-05-15 | 250          |
        | 2014-06-15 | 250          |
      And closed series should be:
        | days       | closed_points |
        | 2013-08-01 | 0             |
        | 2013-09-01 | 15            |
        | 2013-10-01 | 30            |
        | 2013-11-01 | 45            |
        | 2013-12-01 | 60            |
        | 2013-12-15 | 60            |
        | 2014-01-01 | 65            |
        | 2014-01-15 | 70            |
        | 2014-02-01 | 75            |
        | 2014-02-15 | 80            |
        | 2014-03-15 | 100           |
        | 2014-04-15 | 120           |
        | 2014-05-15 | 140           |
        | 2014-06-15 | 160           |

  Scenario: 2nd series overlap before start date of first series
    Given I initialize RbStackedData with closed date 2015-03-01
      And I add the following series "A":
        | days       | total_points | closed_points |
        |2013-08-01  | 100          | 0             |
        |2013-09-01  | 100          | 15            |
        |2013-10-01  | 100          | 30            |
        |2013-11-01  | 110          | 45            |
        |2013-12-01  | 110          | 60            |
        |2014-01-01  | 110          | 65            |
        |2014-02-01  | 110          | 70            |
     And I add the following series "B":
        | days       | total_points | closed_points |
        | 2013-05-01 | 150          | 0             |
        | 2013-06-01 | 150          | 5             |
        | 2013-07-01 | 140          | 10            |
        | 2013-08-01 | 140          | 30            |
        | 2013-09-01 | 140          | 50            |
        | 2013-10-01 | 140          | 70            |
        | 2013-11-01 | 140          | 90            |
        | 2013-12-01 | 140          | 100           |
        | 2014-01-01 | 140          | 110           |
        | 2014-02-01 | 140          | 120           |
        | 2014-03-01 | 140          | 130           |
     And I finish RbStackedData
     Then series 0 should be:
        | days       | total_points |
        |2013-08-01  | 100          |
        |2013-09-01  | 100          |
        |2013-10-01  | 100          |
        |2013-11-01  | 110          |
        |2013-12-01  | 110          |
        |2014-01-01  | 110          |
        |2014-02-01  | 110          |
      And series 1 should be:
        | days       | total_points |
        | 2013-05-01 | 250          |
        | 2013-06-01 | 250          |
        | 2013-07-01 | 240          |
        | 2013-08-01 | 240          |
        | 2013-09-01 | 240          |
        | 2013-10-01 | 240          |
        | 2013-11-01 | 250          |
        | 2013-12-01 | 250          |
        | 2014-01-01 | 250          |
        | 2014-02-01 | 250          |
        | 2014-03-01 | 250          |
      And closed series should be:
        | days       | closed_points |
        | 2013-05-01 | 0             |
        | 2013-06-01 | 5             |
        | 2013-07-01 | 10            |
        | 2013-08-01 | 30            |
        | 2013-09-01 | 65            |
        | 2013-10-01 | 100           |
        | 2013-11-01 | 135           |
        | 2013-12-01 | 160           |
        | 2014-01-01 | 175           |
        | 2014-02-01 | 190           |
        | 2014-03-01 | 200           |

  Scenario: Series has days outside closed day limit
    Given I initialize RbStackedData with closed date 2013-10-01
      And I add the following series "A":
        | days       | total_points | closed_points |
        |2013-08-01  | 100          | 0             |
        |2013-09-01  | 100          | 15            |
        |2013-10-01  | 100          | 30            |
        |2013-11-01  | 110          | 45            |
     And I add the following series "B":
        | days       | total_points | closed_points |
        |2013-08-01  | 100          | 0             |
        |2013-09-01  | 100          | 15            |
        |2013-10-01  | 100          | 30            |
        |2013-11-01  | 110          | 45            |
     And I finish RbStackedData
     Then series 0 should be:
        | days       | total_points |
        |2013-08-01  | 100          |
        |2013-09-01  | 100          |
        |2013-10-01  | 100          |
        |2013-11-01  | 110          |
     Then series 1 should be:
        | days       | total_points |
        |2013-08-01  | 200          |
        |2013-09-01  | 200          |
        |2013-10-01  | 200          |
        |2013-11-01  | 220          |
      And closed series should be:
        | days       | closed_points |
        | 2013-08-01 | 0             |
        | 2013-09-01 | 30            |
        | 2013-10-01 | 60            |

  Scenario: First Series has all days outside closed day limit
    Given I initialize RbStackedData with closed date 2013-07-01
      And I add the following series "A":
        | days       | total_points | closed_points |
        |2013-08-01  | 100          | 0             |
        |2013-09-01  | 100          | 15            |
        |2013-10-01  | 100          | 30            |
        |2013-11-01  | 110          | 45            |
     And I add the following series "B":
        | days       | total_points | closed_points |
        |2013-04-01  | 100          | 0             |
        |2013-05-01  | 100          | 15            |
        |2013-06-01  | 100          | 30            |
        |2013-07-01  | 110          | 45            |
     And I finish RbStackedData
     Then series 0 should be:
        | days       | total_points |
        |2013-08-01  | 100          |
        |2013-09-01  | 100          |
        |2013-10-01  | 100          |
        |2013-11-01  | 110          |
     Then series 1 should be:
        | days       | total_points |
        |2013-04-01  | 200          |
        |2013-05-01  | 200          |
        |2013-06-01  | 200          |
        |2013-07-01  | 210          |
      And closed series should be:
        | days       | closed_points |
        | 2013-04-01 | 0             |
        | 2013-05-01 | 15            |
        | 2013-06-01 | 30            |
        | 2013-07-01 | 45            |

  Scenario: 2nd series has all days outside closed day limit
    Given I initialize RbStackedData with closed date 2013-11-01
      And I add the following series "A":
        | days       | total_points | closed_points |
        |2013-08-01  | 100          | 0             |
        |2013-09-01  | 100          | 15            |
        |2013-10-01  | 100          | 30            |
        |2013-11-01  | 110          | 45            |
     And I add the following series "B":
        | days       | total_points | closed_points |
        |2013-12-01  | 100          | 0             |
        |2014-01-01  | 100          | 15            |
        |2014-02-01  | 100          | 30            |
        |2014-03-01  | 110          | 45            |
     And I finish RbStackedData
     Then series 0 should be:
        | days       | total_points |
        |2013-08-01  | 100          |
        |2013-09-01  | 100          |
        |2013-10-01  | 100          |
        |2013-11-01  | 110          |
     Then series 1 should be:
        | days       | total_points |
        |2013-12-01  | 210          |
        |2014-01-01  | 210          |
        |2014-02-01  | 210          |
        |2014-03-01  | 220          |
      And closed series should be:
        | days       | closed_points |
        | 2013-08-01 | 0             |
        | 2013-09-01 | 15            |
        | 2013-10-01 | 30            |
        | 2013-11-01 | 45            |

  Scenario: Check trendlines and estimated end dates
    Given I initialize RbStackedData with closed date 2013-12-01
      And I add the following series "A":
        | days       | total_points | closed_points |
        | 2013-08-01 | 100          | 0             |
        | 2013-09-01 | 100          | 15            |
        | 2013-10-01 | 100          | 30            |
        | 2013-11-01 | 110          | 45            |
        | 2013-12-01 | 110          | 60            |
     And I finish RbStackedData
    Then series "A" trend end date should be 2014-04-07
